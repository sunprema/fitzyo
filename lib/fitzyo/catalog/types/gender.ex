defmodule Fitzyo.Catalog.Types.Gender do
  @moduledoc "Who a product is designed for. Unisex products fit any group of their age group."
  use Ash.Type.Enum, values: [:men, :women, :unisex, :boys, :girls]

  @doc "The age group a shopper group belongs to."
  def age_group(gender) when gender in [:boys, :girls, "boys", "girls"], do: :youth
  def age_group(_), do: :adult
end
