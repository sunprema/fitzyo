defmodule Fitzyo.Video.S3Ref do
  @moduledoc """
  Lightweight pointer to an asset stored in Tigris (S3-compatible).

  This is the currency passed between Reactor steps. Raw binaries are NEVER
  passed between steps or stored in the database — always use S3Ref.
  """

  @enforce_keys [:bucket, :key]
  defstruct bucket: nil,
            key: nil,
            region: "auto",
            size_bytes: nil,
            content_type: nil,
            duration_seconds: nil

  @doc "Returns a presigned download URL valid for `expires_in` seconds (default 24h)."
  def presigned_url(%__MODULE__{} = ref, expires_in \\ 86_400) do
    config = ExAws.Config.new(:s3)

    ExAws.S3.presigned_url(config, :get, ref.bucket, ref.key,
      expires_in: expires_in,
      virtual_host: false
    )
  end
end
