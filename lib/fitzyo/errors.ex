defmodule Fitzyo.Errors do
  @moduledoc """
  Human- and agent-readable messages for Ash errors.

  `Exception.message/1` on an Ash error class includes bread crumbs and a
  stack trace, which is noise for a shopper or an agent. This pulls out the
  underlying messages, preferring one carrying a FitzYo error code such as
  `VARIANT_UNAVAILABLE: …`.
  """

  @code_pattern ~r/^[A-Z_]+: /

  @doc "The most useful single-line message for an error."
  @spec message(term()) :: String.t()
  def message(%{errors: errors}) when is_list(errors) and errors != [] do
    messages = errors |> Enum.map(&message/1) |> Enum.reject(&(&1 in [nil, ""]))

    Enum.find(
      messages,
      List.first(messages) || "Something went wrong",
      &Regex.match?(@code_pattern, &1)
    )
  end

  def message(%{message: message}) when is_binary(message) and message != "", do: message
  def message(%_{} = exception), do: exception |> Exception.message() |> first_line()
  def message(message) when is_binary(message), do: message
  def message(other), do: inspect(other)

  @doc "The FitzYo error code (`VARIANT_UNAVAILABLE`) embedded in a message, if any."
  @spec code(term()) :: String.t() | nil
  def code(error) do
    case Regex.run(~r/^([A-Z_]+): /, message(error)) do
      [_, code] -> code
      _ -> nil
    end
  end

  defp first_line(text), do: text |> String.split("\n", trim: true) |> List.first() || text
end
