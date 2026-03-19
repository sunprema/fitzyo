defmodule Fitzyo.Workflow.Nodes.AssetLoaderStep do
  @moduledoc """
  Loads a purchased marketplace asset (image, audio, VFX) into the workflow
  as an S3Ref, ready to pass to downstream generation nodes.
  """
  use Fitzyo.NodeStep

  alias Fitzyo.Video.S3Ref

  node_def do
    kind :asset_loader
    label "Asset Loader"
    category :data
    color :teal
    icon "📦"
    description "Loads a marketplace asset into the workflow as an S3Ref"

    output :asset, kind: :s3_ref, doc: "The loaded asset ready for downstream use"
    output :metadata, kind: :map, doc: "Asset metadata: kind, title, author"

    config do
      option :asset_id,
        kind: :string,
        default: ""

      option :asset_kind,
        kind: :atom,
        values: [:background_image, :character_ref, :style_pack, :audio_track, :vfx_overlay],
        default: :background_image
    end
  end

  def run(_arguments, _context, _options) do
    {:ok, %{
      asset: %S3Ref{bucket: "fitzyo-asset-previews", key: "mock/asset.jpg", content_type: "image/jpeg"},
      metadata: %{kind: "background_image", title: "Mock Asset", author: "Fitzyo"}
    }}
  end
end
