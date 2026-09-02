defmodule Fitzyo.Catalog.Types.AgeGroup do
  @moduledoc "Adult or youth sizing."
  use Ash.Type.Enum, values: [:adult, :youth]
end
