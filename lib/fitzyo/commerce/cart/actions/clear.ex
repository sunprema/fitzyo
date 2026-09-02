defmodule Fitzyo.Commerce.Cart.Actions.Clear do
  @moduledoc false
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  @impl true
  def run(input, _opts, context) do
    cart_id = input.arguments.cart_id

    Fitzyo.Commerce.CartItem
    |> Ash.Query.filter(cart_id == ^cart_id)
    |> Ash.bulk_destroy(:destroy, %{}, Ash.Context.to_opts(context))
    |> case do
      %Ash.BulkResult{status: :success} -> :ok
      %Ash.BulkResult{errors: errors} -> {:error, errors}
    end
  end
end
