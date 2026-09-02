defmodule Fitzyo.Catalog.Types.Gender do
  @moduledoc "Who a product is designed for."
  use Ash.Type.Enum, values: [:men, :women, :unisex, :boys, :girls]
end
