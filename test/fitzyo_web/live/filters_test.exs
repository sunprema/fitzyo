defmodule FitzyoWeb.StoreLive.FiltersTest do
  use ExUnit.Case, async: true

  alias FitzyoWeb.StoreLive.Filters

  test "round-trips through query params" do
    filters = %Filters{
      query: "linen",
      category: "shirts",
      gender: "men",
      sizes: ["XL"],
      colors: ["blue", "black"],
      brands: ["Columbia"],
      fits: ["relaxed"],
      activities: ["beach"],
      price_min: Decimal.new("20"),
      price_max: Decimal.new("80")
    }

    params = Filters.to_params(filters)
    assert params["color"] == ["blue", "black"]
    assert params["max"] == "80"
    assert params["gender"] == "men"
    assert Filters.from_params(params) == filters
  end

  test "drops blank, malformed, and unknown values instead of raising" do
    filters =
      Filters.from_params(%{
        "q" => "  ",
        "category" => "",
        "size" => "XL",
        "gender" => "robots",
        "fit" => ["relaxed", "baggy"],
        "min" => "abc",
        "max" => "-5",
        "color" => %{"bad" => "shape"}
      })

    assert filters.query == nil
    assert filters.category == nil
    assert filters.sizes == ["XL"]
    assert filters.gender == nil
    assert filters.fits == ["relaxed"]
    assert filters.price_min == nil
    assert filters.price_max == nil
    assert filters.colors == []
    refute Map.has_key?(Filters.to_params(filters), "q")
  end

  test "toggle adds then removes a value; category toggle resets sizes" do
    filters = %Filters{} |> Filters.toggle("color", "blue") |> Filters.toggle("color", "red")
    assert filters.colors == ["blue", "red"]
    assert Filters.toggle(filters, "color", "blue").colors == ["red"]

    filters = filters |> Filters.toggle_category("shirts") |> Filters.toggle("size", "XL")
    assert filters.sizes == ["XL"]

    assert Filters.toggle_category(filters, "shorts") == %{
             filters
             | category: "shorts",
               sizes: []
           }

    assert Filters.toggle_category(filters, "shirts").category == nil
  end

  test "chips list every active constraint and remove/3 undoes each one" do
    filters =
      %Filters{}
      |> Filters.put_query("linen")
      |> Filters.toggle_category("shirts")
      |> Filters.toggle("brand", "Columbia")
      |> Filters.put_price("10", "90")

    chips = Filters.chips(filters)
    assert Enum.map(chips, & &1.facet) == ["q", "category", "brand", "min", "max"]

    cleared = Enum.reduce(chips, filters, &Filters.remove(&2, &1.facet, &1.value))
    assert cleared == %Filters{}
    refute Filters.active?(cleared)
    assert Filters.active?(filters)
  end
end
