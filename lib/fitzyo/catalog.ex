defmodule Fitzyo.Catalog do
  @moduledoc """
  The retailer's commerce catalog: categories, products, variants, and
  structured size guides.

  This is the retailer side of FitzYo. It knows nothing about the shopper;
  every read action takes only task-relevant constraints (size, color, brand,
  fit, budget) that an agent derives from private context it keeps to itself.
  """

  use Ash.Domain,
    otp_app: :fitzyo

  resources do
    resource Fitzyo.Catalog.Category do
      define :list_categories, action: :read
      define :get_category, action: :read, get_by: [:id]
      define :create_category, action: :create
    end

    resource Fitzyo.Catalog.Product do
      define :list_products, action: :read
      define :get_product, action: :read, get_by: [:id]
      define :search_products, action: :browse, args: [:query]
      define :filter_products, action: :browse
      define :list_brands, action: :distinct_brands
      define :create_product, action: :create
    end

    resource Fitzyo.Catalog.Variant do
      define :get_variant, action: :read, get_by: [:id]
      define :list_variants_for_product, action: :for_product, args: [:product_id]
      define :find_matching_variants, action: :matching
      define :list_colors, action: :distinct_colors
      define :list_sizes_in_category, action: :sizes_in_category, args: [:category]
      define :create_variant, action: :create
    end

    resource Fitzyo.Catalog.SizeGuideEntry do
      define :size_guide_for_product, action: :for_product, args: [:product_id]
      define :create_size_guide_entry, action: :create
    end
  end
end
