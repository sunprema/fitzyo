# Seeds the FitzYo demo retailer with a Hawaii-friendly apparel catalog.
#
#     mix run priv/repo/seeds.exs
#
# Every create action upserts on its stable id, so re-running is safe and
# keeps product/variant ids stable for agents.

defmodule Fitzyo.Seeds.Catalog do
  @moduledoc false

  alias Fitzyo.Catalog

  @colors %{
    "black" => "#111111",
    "white" => "#f5f5f5",
    "navy" => "#1f2a44",
    "blue" => "#2f6fd6",
    "aqua" => "#7fd8e8",
    "teal" => "#2a9d8f",
    "gray" => "#8a8f98",
    "sage" => "#9caf88",
    "olive" => "#6b7f3a",
    "green" => "#2e7d32",
    "khaki" => "#c3b091",
    "sand" => "#d8c3a5",
    "tan" => "#c8a97e",
    "coral" => "#ff7f6e",
    "pink" => "#e8a0bf",
    "red" => "#c62828",
    "yellow" => "#f2c94c"
  }

  @men_tops ~w(S M L XL XXL)
  @women_tops ~w(XS S M L XL)
  @youth ~w(XS S M L XL)
  @men_waist ~w(30 32 34 36 38)
  @men_pants ~w(30x32 32x32 34x32 36x32 38x32 34x34 36x34)
  @women_jeans ~w(26 27 28 29 30 31 32)
  @men_shoes ~w(8 9 10 11 12 13)
  @women_shoes ~w(6 7 8 9 10)
  @kid_shoes ~w(1Y 2Y 3Y 4Y 5Y 6Y)
  @hat_sizes ["S/M", "L/XL"]
  @one_size ["OS"]

  @categories [
    %{id: "shirts", name: "Shirts", position: 1, description: "Tees, tops, and button-ups"},
    %{
      id: "shorts",
      name: "Shorts",
      position: 2,
      description: "Casual, hiking, and everyday shorts"
    },
    %{id: "pants", name: "Pants", position: 3, description: "Jeans, trousers, and hiking pants"},
    %{id: "dresses", name: "Dresses", position: 4, description: "Sundresses and travel dresses"},
    %{
      id: "swimwear",
      name: "Swimwear",
      position: 5,
      description: "Boardshorts, suits, rash guards"
    },
    %{
      id: "shoes",
      name: "Shoes",
      position: 6,
      description: "Sandals, sneakers, and hiking shoes"
    },
    %{id: "accessories", name: "Accessories", position: 7, description: "Hats and sun protection"}
  ]

  # {id, attrs, colors, sizes, size_guide_template, opts}
  @products [
    # ----------------------------------------------------------------- Men
    {"prod_1001",
     %{
       name: "Bahama II Short Sleeve Shirt",
       brand: "Columbia",
       category_id: "shirts",
       price: 45,
       gender: :men,
       fit: :relaxed,
       stretch: :low,
       cut: "relaxed",
       weight: "lightweight",
       material: "nylon",
       activities: ~w(travel beach casual),
       description:
         "Quick-drying, vented fishing shirt with UPF 30 sun protection. A Hawaii staple."
     }, ~w(sage white blue), @men_tops, :men_tops, []},
    {"prod_1002",
     %{
       name: "Capilene Cool Daily Shirt",
       brand: "Patagonia",
       category_id: "shirts",
       price: 49,
       gender: :men,
       fit: :regular,
       stretch: :medium,
       cut: "athletic",
       weight: "lightweight",
       material: "recycled polyester",
       activities: ~w(hiking running travel casual),
       description: "Soft, stretchy, odor-resistant tee that works from trail to town."
     }, ~w(blue black gray), @men_tops, :men_tops, []},
    {"prod_1003",
     %{
       name: "Sea Glass Breezer Linen Shirt",
       brand: "Tommy Bahama",
       category_id: "shirts",
       price: 118,
       gender: :men,
       fit: :relaxed,
       stretch: :none,
       cut: "relaxed",
       weight: "lightweight",
       material: "linen",
       activities: ~w(dinner casual beach),
       description: "Breathable linen camp shirt for dinners and warm evenings."
     }, ~w(white blue coral), @men_tops, :men_tops, out_of_stock: [{"coral", "XXL"}]},
    {"prod_1004",
     %{
       name: "Silver Ridge Utility Lite Long Sleeve",
       brand: "Columbia",
       category_id: "shirts",
       price: 60,
       gender: :men,
       fit: :regular,
       stretch: :low,
       cut: "regular",
       weight: "lightweight",
       material: "nylon",
       activities: ~w(hiking outdoor travel),
       description: "Roll-tab long sleeve with UPF 50 for exposed ridgeline hikes."
     }, ~w(khaki blue gray), @men_tops, :men_tops, []},
    {"prod_1005",
     %{
       name: "Classic Pocket Tee",
       brand: "Levi's",
       category_id: "shirts",
       price: 25,
       gender: :men,
       fit: :regular,
       stretch: :low,
       cut: "regular",
       weight: "midweight",
       material: "cotton",
       activities: ~w(casual),
       description: "Everyday cotton pocket tee."
     }, ~w(white black navy red), @men_tops, :men_tops, out_of_stock: [{"navy", "XL"}]},
    {"prod_1006",
     %{
       name: "Dri-FIT Miler Running Tee",
       brand: "Nike",
       category_id: "shirts",
       price: 35,
       gender: :men,
       fit: :slim,
       stretch: :high,
       cut: "athletic",
       weight: "lightweight",
       material: "polyester",
       activities: ~w(running hiking),
       description: "Sweat-wicking running tee with reflective details."
     }, ~w(black blue yellow), @men_tops, :men_tops, []},
    {"prod_1007",
     %{
       name: "Quandary Hiking Shorts 10\"",
       brand: "Patagonia",
       category_id: "shorts",
       price: 79,
       gender: :men,
       fit: :regular,
       stretch: :medium,
       cut: "regular",
       weight: "lightweight",
       material: "recycled nylon",
       activities: ~w(hiking outdoor travel casual),
       description: "Stretchy, quick-dry hiking short with a 10\" inseam."
     }, ~w(black khaki olive), @men_waist, :men_waist, []},
    {"prod_1008",
     %{
       name: "Baggies Shorts 5\"",
       brand: "Patagonia",
       category_id: "shorts",
       price: 65,
       gender: :men,
       fit: :relaxed,
       stretch: :low,
       cut: "relaxed",
       weight: "lightweight",
       material: "recycled nylon",
       activities: ~w(beach swim casual hiking),
       description: "The do-everything short: swims, hikes, and hangs."
     }, ~w(navy black green coral), @men_tops, :men_tops, []},
    {"prod_1009",
     %{
       name: "Silver Ridge Cargo Short",
       brand: "Columbia",
       category_id: "shorts",
       price: 50,
       gender: :men,
       fit: :relaxed,
       stretch: :low,
       cut: "relaxed",
       weight: "lightweight",
       material: "nylon",
       activities: ~w(hiking outdoor casual),
       description: "Roomy cargo short with UPF 50 and plenty of pockets."
     }, ~w(khaki gray olive), @men_waist, :men_waist, out_of_stock: [{"olive", "36"}]},
    {"prod_1010",
     %{
       name: "405 Standard Denim Shorts",
       brand: "Levi's",
       category_id: "shorts",
       price: 45,
       gender: :men,
       fit: :regular,
       stretch: :low,
       cut: "regular",
       weight: "midweight",
       material: "cotton denim",
       activities: ~w(casual),
       description: "Classic denim shorts that sit at the waist."
     }, ~w(blue black), @men_waist, :men_waist, []},
    {"prod_1011",
     %{
       name: "Everyday 20\" Boardshorts",
       brand: "Quiksilver",
       category_id: "swimwear",
       price: 55,
       gender: :men,
       fit: :regular,
       stretch: :medium,
       cut: "regular",
       weight: "lightweight",
       material: "recycled polyester",
       activities: ~w(beach swim),
       description: "Stretch boardshorts with a 20\" outseam."
     }, ~w(navy black teal), @men_waist, :men_waist, []},
    {"prod_1012",
     %{
       name: "Wavefarer Boardshorts 19\"",
       brand: "Patagonia",
       category_id: "swimwear",
       price: 75,
       gender: :men,
       fit: :regular,
       stretch: :low,
       cut: "regular",
       weight: "lightweight",
       material: "recycled nylon",
       activities: ~w(beach swim),
       description: "Durable surf trunks with a quick-dry finish."
     }, ~w(navy blue olive), @men_waist, :men_waist, []},
    {"prod_1013",
     %{
       name: "511 Slim Fit Jeans",
       brand: "Levi's",
       category_id: "pants",
       price: 70,
       gender: :men,
       fit: :slim,
       stretch: :medium,
       cut: "slim",
       weight: "midweight",
       material: "stretch denim",
       activities: ~w(casual dinner),
       description: "Slim from hip to ankle with a little stretch."
     }, ~w(blue black), @men_pants, :men_pants, []},
    {"prod_1014",
     %{
       name: "Silver Ridge Convertible Pants",
       brand: "Columbia",
       category_id: "pants",
       price: 75,
       gender: :men,
       fit: :regular,
       stretch: :low,
       cut: "regular",
       weight: "lightweight",
       material: "nylon",
       activities: ~w(hiking outdoor travel),
       description: "Zip-off legs turn these hiking pants into shorts."
     }, ~w(khaki gray), @men_pants, :men_pants, []},
    {"prod_1015",
     %{
       name: "Boracay Linen Pants",
       brand: "Tommy Bahama",
       category_id: "pants",
       price: 128,
       gender: :men,
       fit: :relaxed,
       stretch: :none,
       cut: "relaxed",
       weight: "lightweight",
       material: "linen",
       activities: ~w(dinner casual),
       description: "Drawstring linen trousers for resort dinners."
     }, ~w(white sand navy), @men_waist, :men_waist, []},
    {"prod_1016",
     %{
       name: "Hurricane XLT2 Sandal",
       brand: "Teva",
       category_id: "shoes",
       price: 75,
       gender: :men,
       fit: :regular,
       stretch: :none,
       material: "recycled polyester webbing",
       activities: ~w(beach hiking casual),
       description: "Strappy sport sandal that handles trails and tide pools."
     }, ~w(black navy olive), @men_shoes, nil, []},
    {"prod_1017",
     %{
       name: "Pegasus 41",
       brand: "Nike",
       category_id: "shoes",
       price: 140,
       gender: :men,
       fit: :regular,
       stretch: :none,
       material: "engineered mesh",
       activities: ~w(running hiking casual),
       description: "Responsive everyday running shoe."
     }, ~w(black blue white), @men_shoes, nil, out_of_stock: [{"white", "11"}]},
    {"prod_1018",
     %{
       name: "Crestwood Hiking Shoe",
       brand: "Columbia",
       category_id: "shoes",
       price: 80,
       gender: :men,
       fit: :regular,
       stretch: :none,
       material: "suede and mesh",
       activities: ~w(hiking outdoor),
       description: "Low-cut hiker with grippy Omni-Grip outsole."
     }, ~w(gray khaki), @men_shoes, nil, []},
    {"prod_1019",
     %{
       name: "Fanning Flip Flops",
       brand: "Reef",
       category_id: "shoes",
       price: 60,
       gender: :men,
       fit: :regular,
       stretch: :none,
       material: "synthetic nubuck",
       activities: ~w(beach casual),
       description: "Cushioned flip flops with arch support."
     }, ~w(black tan), @men_shoes, nil, []},
    # --------------------------------------------------------------- Women
    {"prod_1020",
     %{
       name: "Tamiami II Short Sleeve Shirt",
       brand: "Columbia",
       category_id: "shirts",
       price: 50,
       gender: :women,
       fit: :relaxed,
       stretch: :low,
       cut: "relaxed",
       weight: "lightweight",
       material: "nylon",
       activities: ~w(travel hiking beach),
       description: "Vented UPF 40 shirt that dries in minutes."
     }, ~w(white blue coral), @women_tops, :women_tops, []},
    {"prod_1021",
     %{
       name: "Capilene Cool Trail Tank",
       brand: "Patagonia",
       category_id: "shirts",
       price: 39,
       gender: :women,
       fit: :regular,
       stretch: :medium,
       cut: "athletic",
       weight: "lightweight",
       material: "recycled polyester",
       activities: ~w(hiking running casual),
       description: "Breathable tank for hot-weather hikes."
     }, ~w(black aqua pink), @women_tops, :women_tops, []},
    {"prod_1022",
     %{
       name: "Coastalina Linen Shirt",
       brand: "Tommy Bahama",
       category_id: "shirts",
       price: 98,
       gender: :women,
       fit: :relaxed,
       stretch: :none,
       cut: "relaxed",
       weight: "lightweight",
       material: "linen",
       activities: ~w(dinner casual beach),
       description: "Airy linen button-up for evenings by the water."
     }, ~w(white coral blue), @women_tops, :women_tops, []},
    {"prod_1023",
     %{
       name: "Essentials Tee",
       brand: "Adidas",
       category_id: "shirts",
       price: 30,
       gender: :women,
       fit: :regular,
       stretch: :low,
       cut: "regular",
       weight: "midweight",
       material: "cotton",
       activities: ~w(casual running),
       description: "Soft cotton tee with a small logo."
     }, ~w(black white pink), @women_tops, :women_tops, []},
    {"prod_1024",
     %{
       name: "Linen Sundress",
       brand: "Tommy Bahama",
       category_id: "dresses",
       price: 148,
       gender: :women,
       fit: :relaxed,
       stretch: :none,
       cut: "a-line",
       weight: "lightweight",
       material: "linen",
       activities: ~w(dinner beach casual),
       description: "Midi-length linen sundress with adjustable straps."
     }, ~w(blue white coral), @women_tops, :women_tops, out_of_stock: [{"coral", "M"}]},
    {"prod_1025",
     %{
       name: "Fleetwith Dress",
       brand: "Patagonia",
       category_id: "dresses",
       price: 89,
       gender: :women,
       fit: :regular,
       stretch: :medium,
       cut: "straight",
       weight: "lightweight",
       material: "recycled polyester",
       activities: ~w(travel casual hiking),
       description: "Packable travel dress with a stretchy, wrinkle-resistant knit."
     }, ~w(navy black green), @women_tops, :women_tops, []},
    {"prod_1026",
     %{
       name: "Sunny Days Sundress",
       brand: "Roxy",
       category_id: "dresses",
       price: 49,
       gender: :women,
       fit: :regular,
       stretch: :low,
       cut: "a-line",
       weight: "lightweight",
       material: "viscose",
       activities: ~w(beach casual),
       description: "Easy throw-on sundress for beach days."
     }, ~w(coral yellow teal), @women_tops, :women_tops, []},
    {"prod_1027",
     %{
       name: "Palm Ridge One-Piece Swimsuit",
       brand: "Roxy",
       category_id: "swimwear",
       price: 78,
       gender: :women,
       fit: :slim,
       stretch: :high,
       cut: "fitted",
       weight: "lightweight",
       material: "recycled nylon",
       activities: ~w(beach swim),
       description: "Supportive one-piece with a scoop back."
     }, ~w(teal black coral), @women_tops, :women_tops, []},
    {"prod_1028",
     %{
       name: "Long-Sleeve Rash Guard",
       brand: "Patagonia",
       category_id: "swimwear",
       price: 69,
       gender: :women,
       fit: :slim,
       stretch: :high,
       cut: "fitted",
       weight: "lightweight",
       material: "recycled nylon",
       activities: ~w(beach swim outdoor),
       description: "UPF 50 rash guard for long snorkel sessions."
     }, ~w(navy aqua), @women_tops, :women_tops, []},
    {"prod_1029",
     %{
       name: "Baggies Shorts 5\" - Women's",
       brand: "Patagonia",
       category_id: "shorts",
       price: 59,
       gender: :women,
       fit: :relaxed,
       stretch: :low,
       cut: "relaxed",
       weight: "lightweight",
       material: "recycled nylon",
       activities: ~w(beach hiking casual swim),
       description: "Water-ready shorts that go from trail to surf."
     }, ~w(navy coral green), @women_tops, :women_tops, []},
    {"prod_1030",
     %{
       name: "Saturday Trail Short",
       brand: "Columbia",
       category_id: "shorts",
       price: 55,
       gender: :women,
       fit: :regular,
       stretch: :medium,
       cut: "regular",
       weight: "lightweight",
       material: "stretch nylon",
       activities: ~w(hiking outdoor travel),
       description: "Stretchy hiking short with UPF 50."
     }, ~w(khaki gray olive), @women_tops, :women_tops, []},
    {"prod_1031",
     %{
       name: "Ribcage Straight Jeans",
       brand: "Levi's",
       category_id: "pants",
       price: 98,
       gender: :women,
       fit: :slim,
       stretch: :medium,
       cut: "straight",
       weight: "midweight",
       material: "stretch denim",
       activities: ~w(casual dinner),
       description: "Ultra-high-rise straight-leg jeans."
     }, ~w(blue black), @women_jeans, :women_jeans, []},
    {"prod_1032",
     %{
       name: "Original Universal Sandal",
       brand: "Teva",
       category_id: "shoes",
       price: 55,
       gender: :women,
       fit: :regular,
       stretch: :none,
       material: "recycled polyester webbing",
       activities: ~w(beach hiking casual),
       description: "The iconic strappy sandal."
     }, ~w(black navy coral), @women_shoes, nil, []},
    {"prod_1033",
     %{
       name: "Free RN",
       brand: "Nike",
       category_id: "shoes",
       price: 100,
       gender: :women,
       fit: :regular,
       stretch: :none,
       material: "knit",
       activities: ~w(running casual),
       description: "Flexible, barefoot-feel running shoe."
     }, ~w(black white pink), @women_shoes, nil, []},
    # ----------------------------------------------------------------- Kids
    {"prod_1034",
     %{
       name: "Kids Bahama Short Sleeve Shirt",
       brand: "Columbia",
       category_id: "shirts",
       price: 32,
       gender: :boys,
       age_group: :youth,
       fit: :relaxed,
       stretch: :low,
       cut: "relaxed",
       weight: "lightweight",
       material: "nylon",
       activities: ~w(travel beach casual),
       description: "Kid-sized version of the classic vented sun shirt."
     }, ~w(blue white green), @youth, :youth, []},
    {"prod_1035",
     %{
       name: "Kids Graphic Tee",
       brand: "Old Navy",
       category_id: "shirts",
       price: 12,
       gender: :unisex,
       age_group: :youth,
       fit: :regular,
       stretch: :low,
       cut: "regular",
       weight: "midweight",
       material: "cotton",
       activities: ~w(casual),
       description: "Soft cotton tee with a surf graphic."
     }, ~w(blue gray yellow red), @youth, :youth, out_of_stock: [{"yellow", "L"}]},
    {"prod_1036",
     %{
       name: "Kids Long-Sleeve Rash Guard",
       brand: "Quiksilver",
       category_id: "swimwear",
       price: 32,
       gender: :boys,
       age_group: :youth,
       fit: :slim,
       stretch: :high,
       cut: "fitted",
       weight: "lightweight",
       material: "recycled polyester",
       activities: ~w(beach swim outdoor),
       description: "UPF 50 rash guard for all-day beach play."
     }, ~w(navy aqua red), @youth, :youth, []},
    {"prod_1037",
     %{
       name: "Kids Everyday Boardshorts",
       brand: "Quiksilver",
       category_id: "swimwear",
       price: 35,
       gender: :boys,
       age_group: :youth,
       fit: :regular,
       stretch: :medium,
       cut: "regular",
       weight: "lightweight",
       material: "recycled polyester",
       activities: ~w(beach swim),
       description: "Quick-dry boardshorts with an elastic waist."
     }, ~w(navy teal black), @youth, :youth, []},
    {"prod_1038",
     %{
       name: "Kids Dri-FIT Shorts",
       brand: "Nike",
       category_id: "shorts",
       price: 25,
       gender: :boys,
       age_group: :youth,
       fit: :regular,
       stretch: :medium,
       cut: "regular",
       weight: "lightweight",
       material: "polyester",
       activities: ~w(running casual hiking),
       description: "Lightweight training shorts for active kids."
     }, ~w(black blue gray), @youth, :youth, []},
    {"prod_1039",
     %{
       name: "Girls Sundress",
       brand: "Roxy",
       category_id: "dresses",
       price: 38,
       gender: :girls,
       age_group: :youth,
       fit: :regular,
       stretch: :low,
       cut: "a-line",
       weight: "lightweight",
       material: "cotton",
       activities: ~w(beach casual dinner),
       description: "Breezy cotton sundress with a tropical print."
     }, ~w(coral yellow), @youth, :youth, []},
    {"prod_1040",
     %{
       name: "Kids Hurricane Sandal",
       brand: "Teva",
       category_id: "shoes",
       price: 45,
       gender: :unisex,
       age_group: :youth,
       fit: :regular,
       stretch: :none,
       material: "recycled polyester webbing",
       activities: ~w(beach hiking casual),
       description: "Tough kids' sport sandal with hook-and-loop straps."
     }, ~w(navy pink black), @kid_shoes, nil, []},
    # ---------------------------------------------------------- Accessories
    {"prod_1041",
     %{
       name: "Bora Bora Booney Hat",
       brand: "Columbia",
       category_id: "accessories",
       price: 30,
       gender: :unisex,
       fit: :regular,
       stretch: :none,
       material: "nylon",
       activities: ~w(beach hiking outdoor),
       description: "Wide-brim UPF 50 hat with a mesh vent."
     }, ~w(sand olive navy), @hat_sizes, nil, []},
    {"prod_1042",
     %{
       name: "Kids Bucket Hat",
       brand: "Old Navy",
       category_id: "accessories",
       price: 10,
       gender: :unisex,
       age_group: :youth,
       fit: :regular,
       stretch: :none,
       material: "cotton",
       activities: ~w(beach casual outdoor),
       description: "Packable cotton bucket hat with UPF 50."
     }, ~w(yellow blue), @hat_sizes, nil, []},
    # ----------------------------------------------------------- More pants
    {"prod_1043",
     %{
       name: "XX Chino Standard Taper",
       brand: "Levi's",
       category_id: "pants",
       price: 60,
       gender: :men,
       fit: :regular,
       stretch: :medium,
       cut: "tapered",
       weight: "midweight",
       material: "stretch cotton twill",
       activities: ~w(casual dinner travel),
       description: "Everyday chinos with a little stretch, dressy enough for dinner."
     }, ~w(khaki navy olive), @men_pants, :men_pants, out_of_stock: [{"olive", "36x32"}]},
    {"prod_1044",
     %{
       name: "Saturday Trail Pants",
       brand: "Columbia",
       category_id: "pants",
       price: 65,
       gender: :women,
       fit: :regular,
       stretch: :medium,
       cut: "straight",
       weight: "lightweight",
       material: "stretch nylon",
       activities: ~w(hiking outdoor travel),
       description: "Quick-dry hiking pants with UPF 50 and a gusseted crotch."
     }, ~w(khaki gray black), @women_jeans, :women_jeans, []},
    {"prod_1045",
     %{
       name: "Palm Coast Linen Pants",
       brand: "Tommy Bahama",
       category_id: "pants",
       price: 118,
       gender: :women,
       fit: :relaxed,
       stretch: :none,
       cut: "wide",
       weight: "lightweight",
       material: "linen",
       activities: ~w(dinner casual beach),
       description: "Wide-leg linen pants that pack flat and shake out wrinkle-free."
     }, ~w(white sand navy), @women_tops, :women_tops, []},
    {"prod_1046",
     %{
       name: "Kids Silver Ridge Pull-On Pants",
       brand: "Columbia",
       category_id: "pants",
       price: 40,
       gender: :boys,
       age_group: :youth,
       fit: :regular,
       stretch: :low,
       cut: "regular",
       weight: "lightweight",
       material: "nylon",
       activities: ~w(hiking travel outdoor),
       description: "Elastic-waist hiking pants that dry fast after a stream crossing."
     }, ~w(khaki gray navy), @youth, :youth, []},
    # --------------------------------------------------------- More dresses
    {"prod_1047",
     %{
       name: "Sunset Wrap Dress",
       brand: "Roxy",
       category_id: "dresses",
       price: 65,
       gender: :women,
       fit: :regular,
       stretch: :low,
       cut: "wrap",
       weight: "lightweight",
       material: "viscose",
       activities: ~w(dinner beach casual),
       description: "Flowy wrap dress with a tie waist for sunset dinners."
     }, ~w(coral navy teal), @women_tops, :women_tops, []},
    {"prod_1048",
     %{
       name: "Island Maxi Dress",
       brand: "Tommy Bahama",
       category_id: "dresses",
       price: 138,
       gender: :women,
       fit: :relaxed,
       stretch: :none,
       cut: "a-line",
       weight: "lightweight",
       material: "cotton voile",
       activities: ~w(dinner casual),
       description: "Ankle-length cotton maxi with a smocked back and pockets."
     }, ~w(blue white sand), @women_tops, :women_tops, out_of_stock: [{"white", "M"}]},
    {"prod_1049",
     %{
       name: "Sanibel Shirt Dress",
       brand: "Columbia",
       category_id: "dresses",
       price: 75,
       gender: :women,
       fit: :regular,
       stretch: :low,
       cut: "straight",
       weight: "lightweight",
       material: "nylon",
       activities: ~w(travel hiking casual),
       description: "UPF 40 shirt dress with a drawcord waist; hikes in the morning, lunch after."
     }, ~w(khaki blue), @women_tops, :women_tops, []},
    {"prod_1050",
     %{
       name: "Girls Twirl Dress",
       brand: "Old Navy",
       category_id: "dresses",
       price: 20,
       gender: :girls,
       age_group: :youth,
       fit: :regular,
       stretch: :medium,
       cut: "a-line",
       weight: "lightweight",
       material: "cotton jersey",
       activities: ~w(casual beach),
       description: "Soft jersey dress with a full skirt made for twirling."
     }, ~w(pink blue yellow), @youth, :youth, []},
    # ----------------------------------------------------- More accessories
    {"prod_1051",
     %{
       name: "Coastal Straw Hat",
       brand: "Roxy",
       category_id: "accessories",
       price: 36,
       gender: :women,
       fit: :regular,
       stretch: :none,
       material: "paper straw",
       activities: ~w(beach casual),
       description: "Wide-brim straw hat with a chin cord for windy beaches."
     }, ~w(tan sand), @hat_sizes, nil, []},
    {"prod_1052",
     %{
       name: "Coolhead II Ball Cap",
       brand: "Columbia",
       category_id: "accessories",
       price: 25,
       gender: :unisex,
       fit: :regular,
       stretch: :none,
       material: "nylon",
       activities: ~w(hiking running casual),
       description: "Sweat-wicking cap with a UPF 50 brim."
     }, ~w(navy gray khaki), @one_size, nil, []},
    {"prod_1053",
     %{
       name: "Polarized Sunglasses",
       brand: "Quiksilver",
       category_id: "accessories",
       price: 45,
       gender: :unisex,
       fit: :regular,
       stretch: :none,
       material: "acetate",
       activities: ~w(beach hiking casual dinner),
       description: "Polarized lenses that cut glare off the water."
     }, ~w(black tan), @one_size, nil, []},
    {"prod_1054",
     %{
       name: "Kids Flexible Sunglasses",
       brand: "Roxy",
       category_id: "accessories",
       price: 18,
       gender: :unisex,
       age_group: :youth,
       fit: :regular,
       stretch: :none,
       material: "rubberized frame",
       activities: ~w(beach casual),
       description: "Bendy UV400 shades that survive being sat on."
     }, ~w(pink blue), @one_size, nil, []},
    {"prod_1055",
     %{
       name: "Atom Sling 8L",
       brand: "Patagonia",
       category_id: "accessories",
       price: 69,
       gender: :unisex,
       fit: :regular,
       stretch: :none,
       material: "recycled nylon",
       activities: ~w(hiking travel sightseeing),
       description: "Crossbody sling for a water bottle, phone, and sunscreen."
     }, ~w(black navy sage), @one_size, nil, []},
    {"prod_1056",
     %{
       name: "Sand-Free Beach Tote",
       brand: "Roxy",
       category_id: "accessories",
       price: 32,
       gender: :unisex,
       fit: :regular,
       stretch: :none,
       material: "mesh",
       activities: ~w(beach),
       description: "Mesh tote that lets the sand fall out before it reaches the car."
     }, ~w(sand navy coral), @one_size, nil, []}
  ]

  def run do
    Enum.each(@categories, &Catalog.create_category!/1)
    images = product_images()

    Enum.each(@products, fn {id, attrs, colors, sizes, guide, opts} ->
      attrs = Map.merge(attrs, %{id: id, image_url: images[id] && images[id].url})
      product = Catalog.create_product!(attrs)
      seed_variants(product, colors, sizes, opts)
      seed_size_guide(product, sizes, guide)
    end)

    IO.puts(
      "Seeded #{length(@categories)} categories and #{length(@products)} products with variants."
    )
  end

  # Unsplash photos keyed by product id; see priv/repo/product_images.exs.
  defp product_images do
    {images, _} = Code.eval_file(Path.join(__DIR__, "product_images.exs"))
    images
  end

  defp seed_variants(product, colors, sizes, opts) do
    out_of_stock = Keyword.get(opts, :out_of_stock, [])

    for {color, ci} <- Enum.with_index(colors), {size, si} <- Enum.with_index(sizes) do
      Catalog.create_variant!(%{
        id: variant_id(product.id, color, size),
        product_id: product.id,
        size: size,
        color: color,
        color_hex: Map.fetch!(@colors, color),
        sku: sku(product, color, size),
        price: product.price,
        inventory_quantity: stock(product.id, color, size, out_of_stock),
        position: ci * 100 + si
      })
    end
  end

  defp seed_size_guide(_product, _sizes, nil), do: :ok

  defp seed_size_guide(product, sizes, template) do
    sizes
    |> Enum.with_index()
    |> Enum.each(fn {size, index} ->
      template
      |> measurements(size)
      |> Map.merge(%{product_id: product.id, size: size, position: index})
      |> Catalog.create_size_guide_entry!()
    end)
  end

  defp variant_id(product_id, color, size), do: "#{product_id}_#{slug(color)}_#{slug(size)}"

  defp slug(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end

  defp sku(product, color, size) do
    brand = product.brand |> String.replace(~r/[^A-Za-z]/, "") |> String.slice(0, 3)
    num = String.replace(product.id, "prod_", "")
    String.upcase("#{brand}#{num}-#{String.slice(color, 0, 3)}-#{slug(size)}")
  end

  # Deterministic pseudo-random stock so the demo is stable between resets.
  defp stock(product_id, color, size, out_of_stock) do
    if {color, size} in out_of_stock do
      0
    else
      1 + rem(:erlang.phash2({product_id, color, size}), 24)
    end
  end

  # -- Size guide templates -------------------------------------------------

  @men_tops_guide %{
    "S" => %{chest_min: 35, chest_max: 37, neck: 14.5, sleeve: 33},
    "M" => %{chest_min: 38, chest_max: 40, neck: 15.5, sleeve: 34},
    "L" => %{chest_min: 41, chest_max: 43, neck: 16.5, sleeve: 35},
    "XL" => %{chest_min: 44, chest_max: 46, neck: 17.5, sleeve: 36},
    "XXL" => %{chest_min: 47, chest_max: 49, neck: 18.5, sleeve: 37}
  }

  @women_tops_guide %{
    "XS" => %{
      chest_min: 31,
      chest_max: 32,
      waist_min: 24,
      waist_max: 25,
      hip_min: 34,
      hip_max: 35
    },
    "S" => %{chest_min: 33, chest_max: 34, waist_min: 26, waist_max: 27, hip_min: 36, hip_max: 37},
    "M" => %{chest_min: 35, chest_max: 36, waist_min: 28, waist_max: 29, hip_min: 38, hip_max: 39},
    "L" => %{chest_min: 37, chest_max: 39, waist_min: 30, waist_max: 32, hip_min: 40, hip_max: 42},
    "XL" => %{
      chest_min: 40,
      chest_max: 42,
      waist_min: 33,
      waist_max: 35,
      hip_min: 43,
      hip_max: 45
    }
  }

  @youth_guide %{
    "XS" => %{chest_min: 23, chest_max: 24, waist_min: 21, waist_max: 22},
    "S" => %{chest_min: 25, chest_max: 26, waist_min: 22, waist_max: 23},
    "M" => %{chest_min: 27, chest_max: 28, waist_min: 23, waist_max: 24},
    "L" => %{chest_min: 29, chest_max: 31, waist_min: 25, waist_max: 26},
    "XL" => %{chest_min: 32, chest_max: 34, waist_min: 27, waist_max: 28}
  }

  defp measurements(:men_tops, size), do: Map.fetch!(@men_tops_guide, size)
  defp measurements(:women_tops, size), do: Map.fetch!(@women_tops_guide, size)
  defp measurements(:youth, size), do: Map.fetch!(@youth_guide, size)

  defp measurements(:men_waist, size) do
    waist = String.to_integer(size)
    %{waist_min: waist, waist_max: waist + 1, hip_min: waist + 6, hip_max: waist + 7}
  end

  defp measurements(:men_pants, size) do
    [waist, inseam] = size |> String.split("x") |> Enum.map(&String.to_integer/1)

    %{
      waist_min: waist,
      waist_max: waist + 1,
      hip_min: waist + 6,
      hip_max: waist + 7,
      inseam: inseam
    }
  end

  defp measurements(:women_jeans, size) do
    waist = String.to_integer(size)
    %{waist_min: waist, waist_max: waist + 1, hip_min: waist + 9, hip_max: waist + 10, inseam: 29}
  end
end

Fitzyo.Seeds.Catalog.run()
