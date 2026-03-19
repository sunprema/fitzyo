defmodule Fitzyo.Workflow.Nodes.FinalExportStep do
  @moduledoc """
  Encodes the assembled video to the target format, uploads to the Tigris
  exports bucket, and returns a 24-hour presigned download URL.
  """
  use Fitzyo.NodeStep

  alias Fitzyo.Video.{S3Store, S3Ref}
  import FFmpex
  use FFmpex.Options

  node_def do
    kind :final_export
    label "Final Export"
    category :assembly
    color :blue
    icon "📤"
    description "Encodes and exports the final video to Tigris"

    input :clip, kind: :s3_ref, required: true
    input :audio_track, kind: :s3_ref, required: false

    output :export, kind: :s3_ref, doc: "Final encoded video in Tigris"
    output :download_url, kind: :string, doc: "Presigned URL valid for 24 hours"
    output :duration, kind: :float, doc: "Total duration of the exported video"

    config do
      option :format,
        kind: :atom,
        values: [:mp4_h264, :mp4_h265, :webm_vp9],
        default: :mp4_h264

      option :resolution,
        kind: :atom,
        values: [:r_720p, :r_1080p, :r_4k],
        default: :r_1080p

      option :bitrate_kbps,
        kind: :integer,
        default: 8000
    end
  end

  def run(arguments, context, options) do
    clip_ref = arguments[:clip]
    execution_id = context[:execution_id] || "unknown"
    format = Keyword.get(options, :format, :mp4_h264)
    resolution = Keyword.get(options, :resolution, :r_1080p)
    bitrate_kbps = Keyword.get(options, :bitrate_kbps, 8000)

    tmp_dir = Path.join(System.tmp_dir!(), "fitzyo_export_#{System.unique_integer([:positive])}")
    File.mkdir_p!(tmp_dir)

    with {:ok, video_binary} <- S3Store.download_binary(clip_ref),
         {:ok, export_path} <- encode_video(video_binary, tmp_dir, format, resolution, bitrate_kbps),
         {:ok, export_ref} <- upload_export(export_path, execution_id, format),
         {:ok, url} <- S3Ref.presigned_url(export_ref) do
      duration = clip_ref.duration_seconds || 0.0
      File.rm_rf(tmp_dir)
      {:ok, %{export: export_ref, download_url: url, duration: duration}}
    else
      {:error, reason} ->
        File.rm_rf(tmp_dir)
        {:error, reason}
    end
  end

  # ── Encoding ─────────────────────────────────────────────────────────────

  defp encode_video(binary, tmp_dir, format, resolution, bitrate_kbps) do
    input_path = Path.join(tmp_dir, "input.mp4")
    ext = format_extension(format)
    output_path = Path.join(tmp_dir, "export#{ext}")
    File.write!(input_path, binary)

    {vcodec, acodec} = codecs_for(format)
    {width, height} = resolution_dims(resolution)

    cmd =
      FFmpex.new_command()
      |> add_global_option(option_y())
      |> add_input_file(input_path)
      |> add_output_file(output_path)
      |> add_file_option(option_vcodec(vcodec))
      |> add_file_option(option_acodec(acodec))
      |> add_file_option(option_b("#{bitrate_kbps}k"))
      |> add_file_option(option_vf("scale=#{width}:#{height}:force_original_aspect_ratio=decrease,pad=#{width}:#{height}:(ow-iw)/2:(oh-ih)/2"))

    case FFmpex.execute(cmd) do
      {:ok, _} -> {:ok, output_path}
      {:error, {_cmd, code, stderr}} -> {:error, {:encoding_failed, code, stderr}}
    end
  end

  defp upload_export(path, execution_id, format) do
    ext = format_extension(format)
    content_type = content_type_for(format)
    key = "exports/#{execution_id}/final#{ext}"
    binary = File.read!(path)
    S3Store.put_binary(binary, key, bucket: S3Store.exports_bucket(), content_type: content_type)
  end

  defp codecs_for(:mp4_h264), do: {"libx264", "aac"}
  defp codecs_for(:mp4_h265), do: {"libx265", "aac"}
  defp codecs_for(:webm_vp9), do: {"libvpx-vp9", "libopus"}

  defp format_extension(:mp4_h264), do: ".mp4"
  defp format_extension(:mp4_h265), do: ".mp4"
  defp format_extension(:webm_vp9), do: ".webm"

  defp content_type_for(:webm_vp9), do: "video/webm"
  defp content_type_for(_), do: "video/mp4"

  defp resolution_dims(:r_720p), do: {1280, 720}
  defp resolution_dims(:r_1080p), do: {1920, 1080}
  defp resolution_dims(:r_4k), do: {3840, 2160}
end
