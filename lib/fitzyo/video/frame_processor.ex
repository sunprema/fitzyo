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

    # Falls back when the NIF is not loaded
    def extract_thumbnail(_video_binary, _offset_ms, _max_width),
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
end
