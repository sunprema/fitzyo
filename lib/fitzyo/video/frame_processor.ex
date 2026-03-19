defmodule Fitzyo.Video.FrameProcessor do
  @moduledoc """
  Elixir wrapper for the VideoProcessor Rust NIF.

  Always go through this module — never call `Native` directly from business logic.

  Slice 1: `extract_thumbnail/3` returns a 1×1 WebP placeholder.
  Slice 4: Real FFmpeg-based frame extraction via the `ffmpeg-next` crate.
  """

  defmodule Native do
    @moduledoc false
    use Rustler, otp_app: :fitzyo, crate: "video_processor"

    def extract_thumbnail(_video_binary, _offset_ms, _max_width),
      do: :erlang.nif_error(:nif_not_loaded)

    def probe_video_metadata(_video_binary),
      do: :erlang.nif_error(:nif_not_loaded)

    def generate_waveform(_video_binary, _num_points),
      do: :erlang.nif_error(:nif_not_loaded)
  end

  @doc """
  Extract a thumbnail frame from a video binary.

  - `video_binary` — raw video bytes (e.g. downloaded from Tigris)
  - `offset_ms` — time offset in milliseconds (0 = first frame)
  - `max_width` — maximum width in pixels; aspect ratio preserved

  Returns `{:ok, webp_binary}` or `{:error, reason}`.
  """
  @spec extract_thumbnail(binary(), non_neg_integer(), pos_integer()) ::
          {:ok, binary()} | {:error, term()}
  def extract_thumbnail(video_binary, offset_ms \\ 0, max_width \\ 320)
      when is_binary(video_binary) and is_integer(offset_ms) and is_integer(max_width) do
    Native.extract_thumbnail(video_binary, offset_ms, max_width)
  end

  @doc """
  Probe basic metadata from a video binary.
  Returns `{:ok, %{duration_s: float, width: integer, height: integer, codec: string}}`.
  """
  @spec probe_video_metadata(binary()) :: {:ok, map()} | {:error, term()}
  def probe_video_metadata(video_binary) when is_binary(video_binary) do
    with {:ok, json_binary} <- Native.probe_video_metadata(video_binary),
         {:ok, map} <- Jason.decode(json_binary, keys: :atoms) do
      {:ok, map}
    end
  end

  @doc """
  Generate a waveform amplitude array from audio in a video binary.
  Returns `{:ok, [float]}` — a list of `num_points` values in [0, 1].
  """
  @spec generate_waveform(binary(), pos_integer()) :: {:ok, [float()]} | {:error, term()}
  def generate_waveform(video_binary, num_points \\ 100)
      when is_binary(video_binary) and is_integer(num_points) do
    with {:ok, json_binary} <- Native.generate_waveform(video_binary, num_points),
         {:ok, list} <- Jason.decode(json_binary) do
      {:ok, list}
    end
  end
end
