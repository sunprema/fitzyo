defmodule Fitzyo.CatalogTest do
  use Fitzyo.DataCase, async: true

  import Fitzyo.CatalogFixtures

  alias Fitzyo.Catalog

  describe "categories" do
    test "are listed in position order" do
      later = category_fixture(%{position: 2})
      earlier = category_fixture(%{position: 1})

      ids = Catalog.list_categories!() |> Enum.map(& &1.id)
      assert Enum.find_index(ids, &(&1 == earlier.id)) < Enum.find_index(ids, &(&1 == later.id))
    end

    test "rejects ids that are not url-safe slugs" do
      assert {:error, %Ash.Error.Invalid{}} = Catalog.create_category(%{id: "Bad Id", name: "x"})
    end
  end

  describe "products" do
    test "creating with the same id upserts instead of duplicating" do
      product = product_fixture(%{name: "Original"})

      updated =
        Catalog.create_product!(%{
          id: product.id,
          name: "Renamed",
          brand: product.brand,
          category_id: product.category_id,
          price: product.price
        })

      assert updated.id == product.id
      assert Catalog.get_product!(product.id).name == "Renamed"
    end

    test "availability, sizes and colors are derived from variants" do
      product = product_fixture()

      variants_fixture(product, ["blue", "red"], ["M", "L"], fn color, _ ->
        if color == "red", do: 0, else: 5
      end)

      loaded =
        Catalog.get_product!(product.id, load: [:available, :sizes, :colors, :available_colors])

      assert loaded.available
      assert Enum.sort(loaded.sizes) == ["L", "M"]
      assert Enum.sort(loaded.colors) == ["blue", "red"]
      assert loaded.available_colors == ["blue"]
    end

    test "a product whose variants are all sold out is not available" do
      product = product_fixture()
      variants_fixture(product, ["blue"], ["M"], 0)

      refute Catalog.get_product!(product.id, load: [:available]).available
    end
  end

  describe "search_products/1" do
    test "matches name, brand and description case-insensitively, one term at a time" do
      category = category_fixture()

      linen =
        product_fixture(%{
          category_id: category.id,
          name: "Breezer Linen Shirt",
          brand: "Tommy Bahama"
        })

      tee =
        product_fixture(%{
          category_id: category.id,
          name: "Pocket Tee",
          brand: "Levi's",
          description: "Everyday cotton"
        })

      variants_fixture(linen, ["white"], ["M"])
      variants_fixture(tee, ["white"], ["M"])

      assert ids(Catalog.search_products!("LINEN")) == [linen.id]
      assert ids(Catalog.search_products!("tommy shirt")) == [linen.id]
      assert ids(Catalog.search_products!("cotton")) == [tee.id]
      assert ids(Catalog.search_products!("cotton linen")) == []
    end

    test "hides products with no stock unless asked" do
      category = category_fixture()
      product = product_fixture(%{category_id: category.id, name: "Ghost Jacket"})
      variants_fixture(product, ["black"], ["M"], 0)

      assert ids(Catalog.search_products!("ghost")) == []
      assert ids(Catalog.search_products!("ghost", %{in_stock_only: false})) == [product.id]
    end
  end

  describe "filter_products/1" do
    setup do
      shirts = category_fixture()
      shorts = category_fixture()

      columbia =
        product_fixture(%{
          category_id: shirts.id,
          brand: "Columbia",
          fit: :relaxed,
          price: Decimal.new("45"),
          activities: ["travel", "beach"]
        })

      patagonia =
        product_fixture(%{
          category_id: shirts.id,
          brand: "Patagonia",
          fit: :regular,
          price: Decimal.new("95"),
          activities: ["hiking"]
        })

      levis_shorts =
        product_fixture(%{
          category_id: shorts.id,
          brand: "Levi's",
          fit: :relaxed,
          price: Decimal.new("40"),
          activities: ["casual"]
        })

      variants_fixture(columbia, ["blue", "sage"], ["L", "XL"])
      # Patagonia only has XL in black; blue only in L.
      variants_fixture(patagonia, ["black"], ["XL"])
      variants_fixture(patagonia, ["blue"], ["L"])
      variants_fixture(levis_shorts, ["blue"], ["34"])

      %{
        shirts: shirts,
        shorts: shorts,
        columbia: columbia,
        patagonia: patagonia,
        levis_shorts: levis_shorts
      }
    end

    test "facets combine with AND; values within a facet combine with OR", ctx do
      result =
        Catalog.filter_products!(%{category: ctx.shirts.id, brands: ["columbia", "PATAGONIA"]})

      assert ids(result) == Enum.sort([ctx.columbia.id, ctx.patagonia.id])

      result =
        Catalog.filter_products!(%{
          category: ctx.shirts.id,
          brands: ["Columbia"],
          fits: ["relaxed"]
        })

      assert ids(result) == [ctx.columbia.id]

      result = Catalog.filter_products!(%{category: ctx.shirts.id, fits: ["slim"]})
      assert ids(result) == []
    end

    test "size and color must be satisfied by the same in-stock variant", ctx do
      # Patagonia has blue and XL, but never blue XL.
      result =
        Catalog.filter_products!(%{category: ctx.shirts.id, sizes: ["xl"], colors: ["Blue"]})

      assert ids(result) == [ctx.columbia.id]

      result =
        Catalog.filter_products!(%{
          category: ctx.shirts.id,
          sizes: ["XL"],
          colors: ["blue", "black"]
        })

      assert ids(result) == Enum.sort([ctx.columbia.id, ctx.patagonia.id])
    end

    test "price bounds, activities and gender narrow results", ctx do
      assert ids(Catalog.filter_products!(%{category: ctx.shirts.id, price_max: 50})) == [
               ctx.columbia.id
             ]

      assert ids(Catalog.filter_products!(%{category: ctx.shirts.id, price_min: 50})) == [
               ctx.patagonia.id
             ]

      assert ids(
               Catalog.filter_products!(%{
                 category: ctx.shirts.id,
                 activities: ["Beach", "dinner"]
               })
             ) == [ctx.columbia.id]

      assert ids(Catalog.filter_products!(%{category: ctx.shirts.id, gender: "women"})) == []
    end

    test "unisex products match any shopper group of their age group", ctx do
      hat = product_fixture(%{category_id: ctx.shirts.id, gender: :unisex, age_group: :adult})

      kids_hat =
        product_fixture(%{category_id: ctx.shirts.id, gender: :unisex, age_group: :youth})

      variants_fixture(hat, ["sand"], ["S/M"])
      variants_fixture(kids_hat, ["blue"], ["S/M"])

      men = ids(Catalog.filter_products!(%{category: ctx.shirts.id, gender: "men"}))
      assert hat.id in men
      assert ctx.columbia.id in men
      refute kids_hat.id in men

      boys = ids(Catalog.filter_products!(%{category: ctx.shirts.id, gender: "boys"}))
      assert boys == [kids_hat.id]

      assert [%{product_id: id}] =
               Catalog.find_matching_variants!(%{
                 category: ctx.shirts.id,
                 gender: "girls",
                 size: "S/M"
               })

      assert id == kids_hat.id
    end

    test "a filter that names a size nobody stocks returns nothing", ctx do
      assert ids(Catalog.filter_products!(%{category: ctx.shirts.id, sizes: ["XXXL"]})) == []
    end

    test "invalid enum values are rejected rather than ignored", ctx do
      assert {:error, %Ash.Error.Invalid{}} =
               Catalog.filter_products(%{category: ctx.shirts.id, fits: ["baggy"]})
    end
  end

  describe "find_matching_variants/1" do
    setup do
      shirts = category_fixture()

      product =
        product_fixture(%{
          category_id: shirts.id,
          brand: "Columbia",
          fit: :relaxed,
          price: Decimal.new("45"),
          activities: ["travel"]
        })

      variants_fixture(product, ["blue", "red"], ["L", "XL"], fn color, size ->
        if color == "red" and size == "XL", do: 0, else: 8
      end)

      %{shirts: shirts, product: product}
    end

    test "returns only in-stock variants satisfying every constraint", ctx do
      matches =
        Catalog.find_matching_variants!(%{
          category: ctx.shirts.id,
          size: "xl",
          colors: ["Blue", "Red"],
          brands: ["columbia"],
          fit: "relaxed",
          activities: ["travel"],
          price_max: 50
        })

      assert Enum.map(matches, & &1.id) == ["#{ctx.product.id}_blue_xl"]
    end

    test "constraints on the product side are applied through the relationship", ctx do
      assert Catalog.find_matching_variants!(%{
               product_id: ctx.product.id,
               size: "L",
               brands: ["Patagonia"]
             }) == []

      assert Catalog.find_matching_variants!(%{
               product_id: ctx.product.id,
               size: "L",
               fit: "slim"
             }) == []

      assert Catalog.find_matching_variants!(%{
               product_id: ctx.product.id,
               size: "L",
               price_max: 10
             }) == []

      assert length(Catalog.find_matching_variants!(%{product_id: ctx.product.id, size: "L"})) ==
               2
    end

    test "sold-out variants can be included explicitly", ctx do
      assert Catalog.find_matching_variants!(%{
               product_id: ctx.product.id,
               size: "XL",
               colors: ["red"]
             }) == []

      [variant] =
        Catalog.find_matching_variants!(
          %{product_id: ctx.product.id, size: "XL", colors: ["red"], in_stock_only: false},
          load: [:available, :inventory_status]
        )

      refute variant.available
      assert variant.inventory_status == "out_of_stock"
    end

    test "inventory_status distinguishes low stock", ctx do
      Catalog.create_variant!(%{
        id: "#{ctx.product.id}_blue_m",
        product_id: ctx.product.id,
        size: "M",
        color: "blue",
        price: ctx.product.price,
        inventory_quantity: 2
      })

      variant = Catalog.get_variant!("#{ctx.product.id}_blue_m", load: [:inventory_status])
      assert variant.inventory_status == "low_stock"
    end
  end

  describe "variants and size guides" do
    test "list_variants_for_product/1 returns variants in position order" do
      product = product_fixture()
      variants_fixture(product, ["blue", "black"], ["S", "M"])

      sizes = product.id |> Catalog.list_variants_for_product!() |> Enum.map(&{&1.color, &1.size})
      assert sizes == [{"blue", "S"}, {"blue", "M"}, {"black", "S"}, {"black", "M"}]
    end

    test "size_guide_for_product/1 returns structured rows in order and upserts per size" do
      product = product_fixture()

      size_guide_fixture(product, [
        %{size: "L", chest_min: 41, chest_max: 43, neck: 16.5},
        %{size: "XL", chest_min: 44, chest_max: 46, neck: 17.5}
      ])

      # Re-seeding the same size updates rather than duplicates.
      Catalog.create_size_guide_entry!(%{
        product_id: product.id,
        size: "XL",
        position: 1,
        chest_min: 44,
        chest_max: 47
      })

      rows = Catalog.size_guide_for_product!(product.id)
      assert Enum.map(rows, & &1.size) == ["L", "XL"]
      assert Enum.map(rows, &Decimal.to_string(&1.chest_max)) == ["43", "47"]
      assert rows |> hd() |> Map.get(:inseam) == nil
    end
  end

  describe "Facets" do
    alias Fitzyo.Catalog.Facets

    test "derives brands, colors, activities and per-category sizes from the catalog" do
      shirts = category_fixture()
      shoes = category_fixture()

      shirt =
        product_fixture(%{
          category_id: shirts.id,
          brand: "Zed Brand",
          activities: ["swim", "dinner"]
        })

      shoe =
        product_fixture(%{category_id: shoes.id, brand: "Alpha Brand", activities: ["beach"]})

      variants_fixture(shirt, ["teal"], ["XL", "S"])
      variants_fixture(shoe, ["teal", "sand"], ["10", "9"])

      facets = Facets.all()

      assert Enum.find(facets.categories, &(&1.id == shirts.id)).product_count == 1

      assert ["Alpha Brand", "Zed Brand"] ==
               Enum.filter(facets.brands, &(&1 in ["Alpha Brand", "Zed Brand"]))

      assert Enum.count(facets.colors, &(&1.name == "teal")) == 1
      assert facets.fits == ["slim", "regular", "relaxed", "oversized"]

      assert ["beach", "swim", "dinner"] ==
               Enum.filter(facets.activities, &(&1 in ["beach", "swim", "dinner"]))

      assert Facets.sizes_for_category(shirts.id) == ["S", "XL"]
      assert Facets.sizes_for_category(shoes.id) == ["9", "10"]
      assert Facets.sizes_for_category(nil) == []
    end
  end

  describe "Sizes.sort/1" do
    alias Fitzyo.Catalog.Sizes

    test "orders letter, waist, pants and youth sizes naturally" do
      assert Sizes.sort(["XL", "S", "XXL", "M", "L", "XS"]) == ["XS", "S", "M", "L", "XL", "XXL"]
      assert Sizes.sort(["36", "30", "34", "32"]) == ["30", "32", "34", "36"]
      assert Sizes.sort(["34x34", "32x32", "34x32"]) == ["32x32", "34x32", "34x34"]
      assert Sizes.sort(["3Y", "1Y", "10.5", "2Y"]) == ["1Y", "2Y", "3Y", "10.5"]
      assert Sizes.sort(["7", "6Y", "6", "5Y"]) == ["5Y", "6Y", "6", "7"]
      assert Sizes.sort(["L/XL", "S/M"]) == ["S/M", "L/XL"]
      assert Sizes.sort(["One Size", "M"]) == ["M", "One Size"]
    end
  end

  defp ids(products), do: products |> Enum.map(& &1.id) |> Enum.sort()
end
