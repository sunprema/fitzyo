defmodule Fitzyo.Catalog.Sizes do
  @moduledoc """
  Orders apparel sizes the way a shopper expects (`S, M, L, XL`, `30, 32, 34`,
  `32x32, 34x32`, `1Y, 2Y`), regardless of how they came out of the database.
  """

  @letter_order ~w(XXS XS S M L XL XXL XXXL)
                |> Enum.with_index()
                |> Map.new()

  @doc "Sorts a list of size labels into display order. Unknown labels sort last, alphabetically."
  @spec sort([String.t()]) :: [String.t()]
  def sort(sizes) when is_list(sizes), do: Enum.sort_by(sizes, &sort_key/1)

  @doc """
  A sort key usable with `Enum.sort_by/2` on any struct or map carrying a `:size`.

  Order: letter sizes (`XS`…`XXXL`, then combined ones like `S/M`), then youth
  numeric sizes (`1Y`…`6Y`), then plain numeric and waist×inseam sizes, then
  anything unrecognised alphabetically.
  """
  @spec sort_key(String.t()) :: tuple()
  def sort_key(size) when is_binary(size) do
    label = size |> String.trim() |> String.upcase()
    [head | _] = String.split(label, "/")

    cond do
      Map.has_key?(@letter_order, label) ->
        {0, Map.fetch!(@letter_order, label), 0, 0, label}

      Map.has_key?(@letter_order, head) ->
        {0, Map.fetch!(@letter_order, head), 1, 0, label}

      match?({:ok, _}, parse_pair(label, "X")) ->
        {:ok, {waist, inseam}} = parse_pair(label, "X")
        {1, 1, waist, inseam, label}

      match?({_, ""}, Float.parse(label)) ->
        {number, ""} = Float.parse(label)
        {1, 1, number, 0, label}

      match?({_, _}, Float.parse(label)) ->
        {number, _suffix} = Float.parse(label)
        {1, 0, number, 0, label}

      true ->
        {2, 0, 0, 0, label}
    end
  end

  defp parse_pair(label, separator) do
    with [a, b] <- String.split(label, separator),
         {waist, ""} <- Integer.parse(a),
         {inseam, ""} <- Integer.parse(b) do
      {:ok, {waist, inseam}}
    else
      _ -> :error
    end
  end
end
