defmodule FitzyoWeb.StoreLive.Members do
  @moduledoc """
  The party: the people an agent is shopping for, registered as **derived**
  constraints only (`register_party_member`). A member is a label the
  shopper uses ("Dad"), a size per size system, colour and brand
  preferences and avoid-lists, a fit, an optional budget, and the shopper
  group to search in. Never a name, an age, a measurement, or a reason: the
  input schema rejects anything else, and so does the server.

  With a member registered, `find_matching_variants` and `filter_products`
  accept `member: "Dad"` and resolve the right size for each category
  themselves: tops are letter sizes, men's bottoms are waists (`36`) or
  waist×inseam (`36x32`), shoes are numeric or youth (`4Y`), hats are
  `S/M`/`L/XL`. Because size and colour must land on the same in-stock
  variant, the union of a member's sizes is safe to send for a search that
  spans categories. Product cards badge every member a product fits, the
  cart and proposals show per-member subtotals against per-member budgets,
  and removing a member clears its badges. All of it lives in this session.
  """

  alias Fitzyo.Catalog.Types

  @size_keys ~w(tops bottoms inseam shoes hats dresses)
  @member_keys ~w(label gender sizes colors exclude_colors brands exclude_brands fit budget)
  @max_members 12

  @type t :: %{
          label: String.t(),
          gender: String.t() | nil,
          sizes: %{optional(String.t()) => String.t()},
          colors: [String.t()],
          exclude_colors: [String.t()],
          brands: [String.t()],
          exclude_brands: [String.t()],
          fit: String.t() | nil,
          budget: Decimal.t() | nil,
          registered_at: DateTime.t()
        }

  # ---------------------------------------------------------------- specs

  def register_spec do
    %{
      name: "register_party_member",
      description:
        "Register someone you are shopping for as derived constraints: the label the shopper uses (\"Dad\"), one size per size system (tops XL, bottoms 36, inseam 32, shoes 11, hats L/XL), preferred and avoided colours and brands, a fit, a budget, and the shopper group. Then pass member: \"Dad\" to find_matching_variants or filter_products and the store resolves the right size for each category; products the member fits are badged in the UI, and the cart and proposals show a per-member subtotal against the budget. Registering the same label again replaces it. Send only what is listed here: no names, ages, measurements, or notes; the store refuses them.",
      input_schema:
        object(
          %{
            label: %{type: "string", description: "As the shopper says it, e.g. \"Dad\""},
            gender: %{type: "string", enum: gender_values()},
            sizes:
              object(%{
                tops: %{
                  type: "string",
                  description: "Letter size for shirts, dresses, swim tops, e.g. XL"
                },
                bottoms: %{
                  type: "string",
                  description: "Waist for shorts, pants, trunks, e.g. 36"
                },
                inseam: %{type: "string", description: "For waist×inseam pants, e.g. 32"},
                shoes: %{type: "string", description: "e.g. 11 or 4Y"},
                hats: %{type: "string", description: "e.g. S/M or L/XL"},
                dresses: %{type: "string", description: "When it differs from tops"}
              }),
            colors: string_array("Preferred colours"),
            exclude_colors: string_array("Colours to avoid; a hard constraint"),
            brands: string_array("Preferred brands"),
            exclude_brands: string_array("Brands to avoid; a hard constraint"),
            fit: %{type: "string", enum: fit_values()},
            budget: %{
              type: "number",
              minimum: 0,
              description: "This person's share of the budget"
            }
          },
          ["label"]
        ),
      annotations: %{readOnlyHint: false, destructive?: false, idempotentHint: true}
    }
  end

  def remove_spec do
    %{
      name: "remove_party_member",
      description:
        "Forget a registered member: their badges, sizes, and budget leave the store UI. The shopper can also do this from the agent panel.",
      input_schema: object(%{label: %{type: "string"}}, ["label"]),
      annotations: %{readOnlyHint: false, destructive?: false, idempotentHint: true}
    }
  end

  # ---------------------------------------------------------------- building

  @doc """
  Validates a registration. Unknown keys are refused by name with
  `PRIVATE_CONTEXT_REJECTED`, so an agent that tries to send a profile
  learns exactly what does not belong on a retailer's server.
  """
  @spec build(map()) :: {:ok, t()} | {:error, map()}
  def build(%{"label" => label} = input) when is_binary(label) do
    label = String.trim(label)
    sizes = input["sizes"] || %{}

    extra =
      (Map.keys(input) -- @member_keys) ++
        Enum.map(Map.keys(sizes_map(sizes)) -- @size_keys, &"sizes.#{&1}")

    with :ok <- check(label != "", "INVALID_OPERATION", "label must not be blank"),
         :ok <-
           check(
             extra == [],
             "PRIVATE_CONTEXT_REJECTED",
             "register_party_member takes derived constraints only; drop: #{Enum.join(extra, ", ")}"
           ),
         :ok <- check(is_map(sizes), "INVALID_OPERATION", "sizes must be an object"),
         {:ok, sizes} <- sizes(sizes),
         {:ok, gender} <- optional_enum(input["gender"], gender_values(), "gender"),
         {:ok, fit} <- optional_enum(input["fit"], fit_values(), "fit"),
         {:ok, budget} <- budget(input["budget"]) do
      {:ok,
       %{
         label: label,
         gender: gender,
         sizes: sizes,
         colors: input["colors"] |> list() |> Enum.map(&String.downcase/1),
         exclude_colors: input["exclude_colors"] |> list() |> Enum.map(&String.downcase/1),
         brands: list(input["brands"]),
         exclude_brands: list(input["exclude_brands"]),
         fit: fit,
         budget: budget,
         registered_at: DateTime.utc_now()
       }}
    end
  end

  def build(_input),
    do: {:error, %{code: "INVALID_OPERATION", message: "register_party_member needs a label"}}

  @doc "Adds or replaces a member, keeping registration order. At most #{@max_members}."
  def put(members, member) do
    case Enum.find_index(members, &(&1.label == member.label)) do
      nil when length(members) >= @max_members -> {:error, "at most #{@max_members} members"}
      nil -> {:ok, members ++ [member]}
      i -> {:ok, List.replace_at(members, i, member)}
    end
  end

  def find(members, label) when is_binary(label),
    do: Enum.find(members, &(String.downcase(&1.label) == String.downcase(String.trim(label))))

  def find(_members, _label), do: nil

  def budget(members, label) when is_list(members) do
    case find(members, label) do
      %{budget: budget} -> budget
      _ -> nil
    end
  end

  # ---------------------------------------------------------------- size resolution

  @doc """
  The size labels that could fit `member` in `category` (nil for any),
  across the catalogue's size systems. Categories are matched by their
  leading word, so `shirts-42` in tests behaves like `shirts`.
  """
  @spec sizes_for(t(), String.t() | nil) :: [String.t()]
  def sizes_for(member, category) do
    s = member.sizes
    pants = s["bottoms"] && s["inseam"] && "#{s["bottoms"]}x#{s["inseam"]}"

    case family(category) do
      "shirt" -> [s["tops"]]
      "dress" -> [s["dresses"] || s["tops"]]
      "short" -> [s["bottoms"], s["tops"]]
      "pant" -> [s["bottoms"], pants, s["tops"]]
      "swim" -> [s["bottoms"], s["tops"]]
      "shoe" -> [s["shoes"]]
      "accessor" -> [s["hats"]]
      "hat" -> [s["hats"]]
      _ -> [s["tops"], s["dresses"], s["bottoms"], pants, s["shoes"], s["hats"]]
    end
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp family(nil), do: nil

  defp family(category) do
    word = category |> String.downcase() |> String.split(~r/[^a-z]+/, trim: true) |> List.first()

    Enum.find(~w(shirt dress short pant swim shoe accessor hat), fn prefix ->
      is_binary(word) and String.starts_with?(word, prefix)
    end)
  end

  # ---------------------------------------------------------------- applying to tool input

  @doc """
  Fills a tool's input from a member wherever the agent left a key out:
  sizes (resolved for the input's category), colours, exclusions, brands,
  fit, gender, and the label. Explicit input always wins.
  """
  @spec apply(map(), [t()]) :: {:ok, map()} | {:error, map()}
  def apply(%{"member" => label} = input, members) when is_binary(label) do
    case find(members, label) do
      nil ->
        known = Enum.map_join(members, ", ", & &1.label)

        {:error,
         %{
           code: "MEMBER_NOT_FOUND",
           message:
             "No registered member #{inspect(label)}; register_party_member first" <>
               if(known != "", do: " (known: #{known})", else: "")
         }}

      member ->
        sizes = sizes_for(member, input["category"])

        merged =
          input
          |> Map.delete("member")
          |> put_default("sizes", if(blank?(input["size"]), do: sizes, else: []))
          |> put_default("color", member.colors)
          |> put_default("exclude_color", member.exclude_colors)
          |> put_default("brand", member.brands)
          |> put_default("exclude_brand", member.exclude_brands)
          |> put_default("fit", member.fit)
          |> put_default("gender", member.gender)
          |> put_default("label", member.label)
          |> Map.put("resolved_for", member.label)

        {:ok, merged}
    end
  end

  def apply(input, _members), do: {:ok, input}

  defp put_default(input, key, value) do
    if blank?(input[key]) and not blank?(value), do: Map.put(input, key, value), else: input
  end

  defp blank?(value), do: value in [nil, "", []]

  # ---------------------------------------------------------------- fit

  @doc "Labels of every member `product` fits: an in-stock variant in one of their sizes and not an avoided colour, within their shopper group."
  def fits(members, product) do
    members
    |> Enum.filter(&fits?(&1, product))
    |> Enum.map(& &1.label)
  end

  @doc "`fits/2` for a list of products, keyed by product id."
  def fits_map([], _products), do: %{}

  def fits_map(members, products) do
    products
    |> Enum.map(&{&1.id, fits(members, &1)})
    |> Enum.reject(fn {_id, labels} -> labels == [] end)
    |> Map.new()
  end

  def fits?(member, product) do
    gender_ok?(member, product) and
      Enum.any?(product.variants, &variant_fits?(member, product, &1))
  end

  @doc "Members whose size this exact variant is (for the size picker), regardless of stock."
  def labels_for_variant(members, product, variant) do
    members
    |> Enum.filter(&(gender_ok?(&1, product) and variant_fits?(&1, product, variant, false)))
    |> Enum.map(& &1.label)
  end

  defp variant_fits?(member, product, variant, need_stock? \\ true) do
    sizes = member |> sizes_for(product.category_id) |> Enum.map(&String.downcase/1)

    String.downcase(variant.size) in sizes and
      String.downcase(variant.color) not in member.exclude_colors and
      (not need_stock? or variant.inventory_quantity > 0)
  end

  defp gender_ok?(%{gender: nil}, _product), do: true

  defp gender_ok?(%{gender: gender}, product) do
    wanted = String.to_existing_atom(gender)

    product.gender == wanted or
      (product.gender == :unisex and product.age_group == Types.Gender.age_group(wanted))
  end

  # ---------------------------------------------------------------- presentation

  @doc "A member as `get_store_state` reports it."
  def summary(member) do
    %{
      label: member.label,
      gender: member.gender,
      sizes: member.sizes,
      colors: member.colors,
      exclude_colors: member.exclude_colors,
      brands: member.brands,
      exclude_brands: member.exclude_brands,
      fit: member.fit,
      budget: member.budget && Decimal.to_float(member.budget)
    }
  end

  @doc "One line for the panel: \"XL · 36 · shoes 11 · blue/black · not red · $250\"."
  def describe(member) do
    s = member.sizes

    [
      s["tops"],
      s["bottoms"] && ((s["inseam"] && "#{s["bottoms"]}x#{s["inseam"]}") || s["bottoms"]),
      s["shoes"] && "shoes #{s["shoes"]}",
      s["hats"] && "hat #{s["hats"]}",
      member.colors != [] && Enum.join(member.colors, "/"),
      member.exclude_colors != [] && "not " <> Enum.join(member.exclude_colors, "/"),
      member.brands != [] && Enum.join(member.brands, ", "),
      member.fit,
      member.budget && "$" <> Decimal.to_string(Decimal.round(member.budget, 0), :normal)
    ]
    |> Enum.reject(&(&1 in [nil, false, ""]))
    |> Enum.join(" · ")
  end

  # ---------------------------------------------------------------- internals

  defp sizes(sizes) do
    sizes = sizes_map(sizes)

    if Enum.all?(sizes, fn {_k, v} -> is_binary(v) end) do
      {:ok,
       sizes
       |> Enum.map(fn {k, v} -> {k, String.trim(v)} end)
       |> Enum.reject(fn {_k, v} -> v == "" end)
       |> Map.new()}
    else
      {:error, %{code: "INVALID_OPERATION", message: "every size must be a string"}}
    end
  end

  defp sizes_map(sizes) when is_map(sizes), do: sizes
  defp sizes_map(_), do: %{}

  defp optional_enum(nil, _values, _field), do: {:ok, nil}
  defp optional_enum("", _values, _field), do: {:ok, nil}

  defp optional_enum(value, values, field) when is_binary(value) do
    value = String.downcase(value)

    if value in values,
      do: {:ok, value},
      else:
        {:error,
         %{code: "INVALID_FILTER", message: "#{field} must be one of #{Enum.join(values, ", ")}"}}
  end

  defp optional_enum(_value, values, field),
    do:
      {:error,
       %{code: "INVALID_FILTER", message: "#{field} must be one of #{Enum.join(values, ", ")}"}}

  defp budget(nil), do: {:ok, nil}
  defp budget(n) when is_integer(n) and n >= 0, do: {:ok, Decimal.new(n)}
  defp budget(n) when is_float(n) and n >= 0, do: {:ok, Decimal.from_float(n)}

  defp budget(_),
    do: {:error, %{code: "INVALID_OPERATION", message: "budget must be a non-negative number"}}

  defp check(true, _code, _message), do: :ok
  defp check(false, code, message), do: {:error, %{code: code, message: message}}

  defp list(nil), do: []
  defp list(value) when is_binary(value), do: [String.trim(value)]

  defp list(values) when is_list(values),
    do:
      values |> Enum.filter(&is_binary/1) |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))

  defp list(_), do: []

  defp fit_values, do: Enum.map(Types.Fit.values(), &Atom.to_string/1)
  defp gender_values, do: Enum.map(Types.Gender.values(), &Atom.to_string/1)

  defp object(properties, required \\ []) do
    schema = %{type: "object", properties: properties, additionalProperties: false}
    if required == [], do: schema, else: Map.put(schema, :required, required)
  end

  defp string_array(description),
    do: %{type: "array", items: %{type: "string"}, description: description}
end
