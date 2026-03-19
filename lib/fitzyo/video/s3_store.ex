defmodule Fitzyo.Video.S3Store do
  @moduledoc """
  All Tigris/S3 operations. Returns S3Ref structs — never raw binaries.
  """

  alias Fitzyo.Video.S3Ref

  @clips_bucket "fitzyo-video-clips"
  @exports_bucket "fitzyo-video-exports"

  @doc "Download raw bytes from an S3Ref."
  def download_binary(%S3Ref{bucket: bucket, key: key}) do
    case ExAws.S3.get_object(bucket, key) |> ExAws.request() do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Fetch a remote URL and store the result in Tigris. Returns S3Ref."
  def store_from_url(url, key, opts \\ []) do
    bucket = Keyword.get(opts, :bucket, @clips_bucket)
    content_type = Keyword.get(opts, :content_type, "video/mp4")

    with {:ok, %{body: body, status_code: 200}} <- Req.get(url),
         {:ok, _} <-
           ExAws.S3.put_object(bucket, key, body,
             content_type: content_type
           )
           |> ExAws.request() do
      {:ok,
       %S3Ref{
         bucket: bucket,
         key: key,
         size_bytes: byte_size(body),
         content_type: content_type
       }}
    end
  end

  @doc "Upload raw binary to Tigris. Returns S3Ref."
  def put_binary(binary, key, opts \\ []) when is_binary(binary) do
    bucket = Keyword.get(opts, :bucket, @clips_bucket)
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    case ExAws.S3.put_object(bucket, key, binary, content_type: content_type) |> ExAws.request() do
      {:ok, _} ->
        {:ok,
         %S3Ref{
           bucket: bucket,
           key: key,
           size_bytes: byte_size(binary),
           content_type: content_type
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def clips_bucket, do: @clips_bucket
  def exports_bucket, do: @exports_bucket
end
