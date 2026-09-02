defmodule Fitzyo.Catalog.Types.Fit do
  @moduledoc "How a garment is cut relative to the body."
  use Ash.Type.Enum, values: [:slim, :regular, :relaxed, :oversized]
end
