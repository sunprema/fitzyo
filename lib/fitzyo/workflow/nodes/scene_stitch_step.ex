defmodule Fitzyo.Workflow.Nodes.SceneStitchStep do
  @moduledoc """
  Concatenates multiple video clips into a single output clip using FFmpeg.

  Downloads each S3Ref clip to a temp directory, writes an FFmpeg concat
  list, runs concatenation via System.cmd, uploads to Tigris, and cleans up.
  """
  use Fitzyo.NodeStep

  alias Fitzyo.Video.{S3Store, FrameProcessor}

  node_def do
    kind :scene_stitch
    label "Scene Stitch"
    category :assembly
    color :blue
    icon "🎞️"
    description "Concatenates video clips with optional transitions"

    input :clips, kind: :list, required: true
    input :audio_track, kind: :s3_ref, required: false

    output :clip, kind: :s3_ref, doc: "Stitched output video"
    output :thumbnail, kind: :s3_ref, doc: "Thumbnail of the first frame"
    output :duration, kind: :float, doc: "Total duration in seconds"

    config do
      option :transition,
        kind: :atom,
        values: [:cut, :dissolve, :wipe_left, :wipe_right, :fade_black],
        default: :cut

      option :transition_duration_ms,
        kind: :integer,
        default: 500
    end
  end

  def run(arguments, context, _options) do
    clips = arguments[:clips] || []
    execution_id = context[:execution_id] || "unknown"

    with :ok <- validate_clips(clips),
         {:ok, tmp_dir} <- make_tmp_dir(),
         {:ok, local_paths} <- download_clips(clips, tmp_dir),
         {:ok, output_path} <- concat_clips(local_paths, tmp_dir),
         {:ok, clip_ref} <- upload_output(output_path, execution_id),
         {:ok, thumb_ref} <- extract_and_upload_thumbnail(output_path, execution_id),
         duration <- clip_duration(clips) do
      cleanup(tmp_dir)
      {:ok, %{clip: clip_ref, thumbnail: thumb_ref, duration: duration}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # ── Helpers ──────────────────────────────────────────────────────────────

  defp validate_clips([]), do: {:error, :no_clips}
  defp validate_clips(clips) when is_list(clips), do: :ok

  defp make_tmp_dir do
    dir = Path.join(System.tmp_dir!(), "fitzyo_stitch_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    {:ok, dir}
  end

  defp download_clips(clips, tmp_dir) do
    results =
      clips
      |> Enum.with_index()
      |> Enum.map(fn {clip_ref, idx} ->
        local_path = Path.join(tmp_dir, "clip_#{idx}.mp4")

        with {:ok, binary} <- S3Store.download_binary(clip_ref) do
          File.write!(local_path, binary)
          {:ok, local_path}
        end
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil -> {:ok, Enum.map(results, fn {:ok, path} -> path end)}
      err -> err
    end
  end

  defp concat_clips([single_path], _tmp_dir), do: {:ok, single_path}

  defp concat_clips(paths, tmp_dir) do
    list_path = Path.join(tmp_dir, "concat.txt")
    output_path = Path.join(tmp_dir, "stitched.mp4")

    list_content = Enum.map_join(paths, "\n", fn p -> "file '#{p}'" end)
    File.write!(list_path, list_content)

    case System.cmd("ffmpeg", ["-y", "-f", "concat", "-safe", "0", "-i", list_path, "-c", "copy", output_path],
           stderr_to_stdout: true
         ) do
      {_, 0} -> {:ok, output_path}
      {stderr, code} -> {:error, {:ffmpeg_failed, code, stderr}}
    end
  end

  defp upload_output(path, execution_id) do
    binary = File.read!(path)
    key = "workflows/executions/#{execution_id}/stitch_#{System.unique_integer([:positive])}.mp4"
    S3Store.put_binary(binary, key, content_type: "video/mp4")
  end

  defp extract_and_upload_thumbnail(video_path, execution_id) do
    binary = File.read!(video_path)

    with {:ok, webp} <- FrameProcessor.extract_thumbnail(binary, 0, 640) do
      key = "workflows/executions/#{execution_id}/thumb_#{System.unique_integer([:positive])}.webp"
      S3Store.put_binary(webp, key, content_type: "image/webp")
    end
  end

  defp clip_duration(clips) do
    clips
    |> Enum.map(fn ref -> ref.duration_seconds || 0.0 end)
    |> Enum.sum()
  end

  defp cleanup(dir), do: File.rm_rf(dir)
end
