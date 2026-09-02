defmodule Fitzyo.Catalog.Types.Stretch do
  @moduledoc "How much a fabric stretches."
  use Ash.Type.Enum, values: [:none, :low, :medium, :high]
end
