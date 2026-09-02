defmodule Fitzyo.Commerce.Types.LineSource do
  @moduledoc """
  Who put a line in the cart: the human directly, an agent tool call, or an
  agent proposal the human accepted as a whole.
  """
  use Ash.Type.Enum, values: [:human, :agent, :proposal]
end
