# Product photos for the demo catalog, chosen from Unsplash search results.
#
# Every photo is under the Unsplash License (free to use, no attribution
# required; credit is given here and in the README anyway). Images are
# hotlinked from images.unsplash.com, so the catalog needs network access
# to show them; `product_art` falls back to the color tile otherwise.
#
# Managed by .claude/skills/product-images (the `product-images` skill).

%{
  # Bahama II Short Sleeve Shirt
  "prod_1001" => %{
    url:
      "https://images.unsplash.com/photo-1592961720879-a1256f7a900f?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "man in white button up shirt and black shorts sitting on wooden bench",
    photographer: "Benjamin R.",
    username: "dapperprofessional",
    link:
      "https://unsplash.com/photos/man-in-white-button-up-shirt-and-black-shorts-sitting-on-wooden-bench-l4iphpLvxBg"
  },
  # Capilene Cool Daily Shirt
  "prod_1002" => %{
    url:
      "https://images.unsplash.com/photo-1717127036020-83774f354008?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a polo shirt with a bee embroidered on the chest",
    photographer: "TuanAnh Blue",
    username: "blueeyeaa",
    link:
      "https://unsplash.com/photos/a-polo-shirt-with-a-bee-embroidered-on-the-chest-M-MwtidrO1g"
  },
  # Sea Glass Breezer Linen Shirt
  "prod_1003" => %{
    url:
      "https://images.unsplash.com/photo-1718862458505-b8d9a68f8a7e?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "A man in a white shirt and sunglasses",
    photographer: "GlassesShop",
    username: "glassesshop_9",
    link: "https://unsplash.com/photos/a-man-in-a-white-shirt-and-sunglasses-b5sQPkBDDOE"
  },
  # Silver Ridge Utility Lite Long Sleeve
  "prod_1004" => %{
    url:
      "https://images.unsplash.com/photo-1740711152088-88a009e877bb?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "A blue shirt hanging on a white wall",
    photographer: "Robert Richman",
    username: "linenese_lifestyle",
    link: "https://unsplash.com/photos/a-blue-shirt-hanging-on-a-white-wall-vcTKFYNZop4"
  },
  # Classic Pocket Tee
  "prod_1005" => %{
    url:
      "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "man wearing white crew-neck t-shirts",
    photographer: "Anomaly",
    username: "anomaly",
    link: "https://unsplash.com/photos/man-wearing-white-crew-neck-t-shirts-WWesmHEgXDs"
  },
  # Dri-FIT Miler Running Tee
  "prod_1006" => %{
    url:
      "https://images.unsplash.com/photo-1713929644020-1cdf48ca0d12?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a pair of headphones, a pair of sneakers, and a t - shirt",
    photographer: "TuanAnh Blue",
    username: "blueeyeaa",
    link:
      "https://unsplash.com/photos/a-pair-of-headphones-a-pair-of-sneakers-and-a-t-shirt-JUrNzQiFJB8"
  },
  # Quandary Hiking Shorts 10\
  "prod_1007" => %{
    url:
      "https://images.unsplash.com/photo-1583165620031-a5dabb0c07df?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "man in gray hoodie standing on rocky shore during daytime",
    photographer: "Jay Mullings",
    username: "writtenmirror",
    link:
      "https://unsplash.com/photos/man-in-gray-hoodie-standing-on-rocky-shore-during-daytime-AhGIGeYoaNc"
  },
  # Baggies Shorts 5\
  "prod_1008" => %{
    url:
      "https://images.unsplash.com/photo-1780323561668-1e648ea2002b?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "A person's legs sinking into soft sand on a beach",
    photographer: "Kier Allen",
    username: "kallen2396",
    link:
      "https://unsplash.com/photos/a-persons-legs-sinking-into-soft-sand-on-a-beach-Ys_82EWSYu0"
  },
  # Silver Ridge Cargo Short
  "prod_1009" => %{
    url:
      "https://images.unsplash.com/photo-1617951907145-53f6eb87a3a3?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "man in blue shorts standing on brown sand during daytime",
    photographer: "Kristino Boxers",
    username: "kristinoboxers",
    link:
      "https://unsplash.com/photos/man-in-blue-shorts-standing-on-brown-sand-during-daytime-7km_eNGl_qA"
  },
  # 405 Standard Denim Shorts
  "prod_1010" => %{
    url:
      "https://images.unsplash.com/photo-1714143136367-7bb68f3f0669?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "the back of a pair of blue jeans",
    photographer: "TuanAnh Blue",
    username: "blueeyeaa",
    link: "https://unsplash.com/photos/the-back-of-a-pair-of-blue-jeans-UinXCaBz44A"
  },
  # Everyday 20\
  "prod_1011" => %{
    url:
      "https://images.unsplash.com/photo-1649690436246-0fdc574de13d?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a man carrying a surfboard while walking down a street",
    photographer: "David Huck",
    username: "davidhuckphotos",
    link:
      "https://unsplash.com/photos/a-man-carrying-a-surfboard-while-walking-down-a-street-JKDKfihIYSw"
  },
  # Wavefarer Boardshorts 19\
  "prod_1012" => %{
    url:
      "https://images.unsplash.com/photo-1617952236317-0bd127407984?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "topless man in red shorts and white sneakers standing beside brown wooden bench",
    photographer: "Kristino Boxers",
    username: "kristinoboxers",
    link:
      "https://unsplash.com/photos/topless-man-in-red-shorts-and-white-sneakers-standing-beside-brown-wooden-bench-MDWZ9H6oG7w"
  },
  # 511 Slim Fit Jeans
  "prod_1013" => %{
    url:
      "https://images.unsplash.com/photo-1714143136372-ddaf8b606da7?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a pair of blue jeans on a white background",
    photographer: "TuanAnh Blue",
    username: "blueeyeaa",
    link: "https://unsplash.com/photos/a-pair-of-blue-jeans-on-a-white-background-9yoXrG6Er_g"
  },
  # Silver Ridge Convertible Pants
  "prod_1014" => %{
    url:
      "https://images.unsplash.com/photo-1625492601206-6d017f130ca6?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "man in blue shirt and brown pants walking on bridge during daytime",
    photographer: "Patrick Pahlke",
    username: "p_pixels_p",
    link:
      "https://unsplash.com/photos/man-in-blue-shirt-and-brown-pants-walking-on-bridge-during-daytime-chEYjgqdJ7k"
  },
  # Boracay Linen Pants
  "prod_1015" => %{
    url:
      "https://images.unsplash.com/photo-1715624133436-d3d449d126ea?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a man standing on the side of a street next to a traffic light",
    photographer: "Lumière Rezaie",
    username: "lumiere_rz",
    link:
      "https://unsplash.com/photos/a-man-standing-on-the-side-of-a-street-next-to-a-traffic-light-9ltxM39Vt3w"
  },
  # Hurricane XLT2 Sandal
  "prod_1016" => %{
    url:
      "https://images.unsplash.com/photo-1742392888098-dfd806a8a9f9?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "Colorful sandals are worn with matching socks",
    photographer: "STONES and BONES",
    username: "stones_and_bones",
    link: "https://unsplash.com/photos/colorful-sandals-are-worn-with-matching-socks-0LyW3nbUUq0"
  },
  # Pegasus 41
  "prod_1017" => %{
    url:
      "https://images.unsplash.com/photo-1491553895911-0055eca6402d?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "unpaired gray Nike running shoe",
    photographer: "Imani Bahati",
    username: "imani_bht",
    link: "https://unsplash.com/photos/unpaired-gray-nike-running-shoe-LxVxPA1LOVM"
  },
  # Crestwood Hiking Shoe
  "prod_1018" => %{
    url:
      "https://images.unsplash.com/photo-1779989301717-c4e3daff27b3?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "Person's legs over cliff edge with mountains and lake",
    photographer: "Nicholas Martinelli",
    username: "nickmartinelli98",
    link:
      "https://unsplash.com/photos/persons-legs-over-cliff-edge-with-mountains-and-lake-AQdDI_i2JZE"
  },
  # Fanning Flip Flops
  "prod_1019" => %{
    url:
      "https://images.unsplash.com/photo-1659963970293-b12cfeb286c5?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a pair of flip flops on the sand",
    photographer: "David Trinks",
    username: "dtrinksrph",
    link: "https://unsplash.com/photos/a-pair-of-flip-flops-on-the-sand-glfcz6er-nA"
  },
  # Tamiami II Short Sleeve Shirt
  "prod_1020" => %{
    url:
      "https://images.unsplash.com/photo-1625136218237-80ab65d4b467?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "woman in white long sleeve shirt and white pants standing on beach during daytime",
    photographer: "Asal Mshk",
    username: "asalmashkoori",
    link:
      "https://unsplash.com/photos/woman-in-white-long-sleeve-shirt-and-white-pants-standing-on-beach-during-daytime-X9xNsLLngnE"
  },
  # Capilene Cool Trail Tank
  "prod_1021" => %{
    url:
      "https://images.unsplash.com/photo-1563903260263-065d1c592e6b?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "woman in black sports bra sitting on rock formation",
    photographer: "Alex Gorey",
    username: "alexgorey",
    link:
      "https://unsplash.com/photos/woman-in-black-sports-bra-sitting-on-rock-formation-1dd5-wBwdZc"
  },
  # Coastalina Linen Shirt
  "prod_1022" => %{
    url:
      "https://images.unsplash.com/photo-1625136217041-171e27168e97?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "woman in white hijab and white and red floral dress standing on beach during daytime",
    photographer: "Asal Mshk",
    username: "asalmashkoori",
    link:
      "https://unsplash.com/photos/woman-in-white-hijab-and-white-and-red-floral-dress-standing-on-beach-during-daytime-7YisgHbaWfQ"
  },
  # Essentials Tee
  "prod_1023" => %{
    url:
      "https://images.unsplash.com/photo-1632828168989-f8ec4e827156?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a woman with her hands on her hips",
    photographer: "Ben Masora",
    username: "benmasora",
    link: "https://unsplash.com/photos/a-woman-with-her-hands-on-her-hips-cMPK7fh743Q"
  },
  # Linen Sundress
  "prod_1024" => %{
    url:
      "https://images.unsplash.com/photo-1722261124376-4aede6aeb86c?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "A woman standing in a field of tall grass",
    photographer: "Deny Hill",
    username: "deny_hill",
    link: "https://unsplash.com/photos/a-woman-standing-in-a-field-of-tall-grass-WxvhVMSc2TM"
  },
  # Fleetwith Dress
  "prod_1025" => %{
    url:
      "https://images.unsplash.com/photo-1596703343516-57c8fe6282d7?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "woman in black long sleeve dress holding black leather handbag",
    photographer: "Laura Chouette",
    username: "laurachouette",
    link:
      "https://unsplash.com/photos/woman-in-black-long-sleeve-dress-holding-black-leather-handbag-LDx5dWiyxOM"
  },
  # Sunny Days Sundress
  "prod_1026" => %{
    url:
      "https://images.unsplash.com/photo-1644575956368-081c7383141a?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a woman in a yellow dress on the beach",
    photographer: "Michael Lee",
    username: "guoshiwushuang",
    link: "https://unsplash.com/photos/a-woman-in-a-yellow-dress-on-the-beach-i-2dzPJ7sSU"
  },
  # Palm Ridge One-Piece Swimsuit
  "prod_1027" => %{
    url:
      "https://images.unsplash.com/photo-1699297725709-0e13fb522564?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a woman in a white swimsuit sitting on the beach",
    photographer: "Joseph Kellner",
    username: "jkellner",
    link:
      "https://unsplash.com/photos/a-woman-in-a-white-swimsuit-sitting-on-the-beach-CBMdPg2i7_Y"
  },
  # Long-Sleeve Rash Guard
  "prod_1028" => %{
    url:
      "https://images.unsplash.com/photo-1585497733795-1c6dfa087608?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "woman in black and red jacket holding blue surfboard on beach during daytime",
    photographer: "Miguel A Amutio",
    username: "amutiomi",
    link:
      "https://unsplash.com/photos/woman-in-black-and-red-jacket-holding-blue-surfboard-on-beach-during-daytime-AGgvxJ4Nn0Y"
  },
  # Baggies Shorts 5\
  "prod_1029" => %{
    url:
      "https://images.unsplash.com/photo-1676328012648-ee16da2e08d8?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a woman sitting on a picnic table in a bikini",
    photographer: "Joseph Kellner",
    username: "jkellner",
    link: "https://unsplash.com/photos/a-woman-sitting-on-a-picnic-table-in-a-bikini-DHWTYMcGlwc"
  },
  # Saturday Trail Short
  "prod_1030" => %{
    url:
      "https://images.unsplash.com/photo-1646814252313-371da4716370?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a woman walking down a dirt road in the woods",
    photographer: "Kakasi Kriszta",
    username: "kakasikriszta",
    link: "https://unsplash.com/photos/a-woman-walking-down-a-dirt-road-in-the-woods-XSnBW4faTaU"
  },
  # Ribcage Straight Jeans
  "prod_1031" => %{
    url:
      "https://images.unsplash.com/photo-1714143164072-7646ef5cb24d?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a pair of dark blue jeans on a white background",
    photographer: "TuanAnh Blue",
    username: "blueeyeaa",
    link:
      "https://unsplash.com/photos/a-pair-of-dark-blue-jeans-on-a-white-background-wNP79A-_bRY"
  },
  # Original Universal Sandal
  "prod_1032" => %{
    url:
      "https://images.unsplash.com/photo-1645923232373-1045b2080c88?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a woman standing on top of a large rock",
    photographer: "Olivia Hibbins",
    username: "olivia_hibbins",
    link: "https://unsplash.com/photos/a-woman-standing-on-top-of-a-large-rock-lts0j_goWfc"
  },
  # Free RN
  "prod_1033" => %{
    url:
      "https://images.unsplash.com/photo-1608667508764-33cf0726b13a?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "white and red nike athletic shoe",
    photographer: "Artem Bondarchuk",
    username: "artembondarchuk",
    link: "https://unsplash.com/photos/white-and-red-nike-athletic-shoe-XPBYi4K8vFI"
  },
  # Kids Bahama Short Sleeve Shirt
  "prod_1034" => %{
    url:
      "https://images.unsplash.com/photo-1624612718797-7e9d4f4fc740?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "woman in white shirt standing on brown wooden dock near body of water during daytime",
    photographer: "Kaŕeem Saleh",
    username: "kareem_saleh",
    link:
      "https://unsplash.com/photos/woman-in-white-shirt-standing-on-brown-wooden-dock-near-body-of-water-during-daytime-HPrYFfXJZ_8"
  },
  # Kids Graphic Tee
  "prod_1035" => %{
    url:
      "https://images.unsplash.com/photo-1583656346517-4716a62e27b7?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "man in black crew neck t-shirt wearing blue knit cap",
    photographer: "rade nugroho",
    username: "rade_nugroho",
    link:
      "https://unsplash.com/photos/man-in-black-crew-neck-t-shirt-wearing-blue-knit-cap-7vQz3JSfEe4"
  },
  # Kids Long-Sleeve Rash Guard
  "prod_1036" => %{
    url:
      "https://images.unsplash.com/photo-1640860040660-78491c1224e3?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a couple of kids that are playing in the sand",
    photographer: "Callum Hill",
    username: "inkyhills",
    link: "https://unsplash.com/photos/a-couple-of-kids-that-are-playing-in-the-sand-8YrGWVExab4"
  },
  # Kids Everyday Boardshorts
  "prod_1037" => %{
    url:
      "https://images.unsplash.com/photo-1640860043823-d2fa539aa678?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a young boy is running in the water at the beach",
    photographer: "Callum Hill",
    username: "inkyhills",
    link:
      "https://unsplash.com/photos/a-young-boy-is-running-in-the-water-at-the-beach--Ywz0sVV2nw"
  },
  # Kids Dri-FIT Shorts
  "prod_1038" => %{
    url:
      "https://images.unsplash.com/photo-1759313560190-d160c3567170?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "Young boy in baseball outfit on yellow background",
    photographer: "Modupe Falade",
    username: "memoriesbymodupe",
    link:
      "https://unsplash.com/photos/young-boy-in-baseball-outfit-on-yellow-background-aazbRqul9cg"
  },
  # Girls Sundress
  "prod_1039" => %{
    url:
      "https://images.unsplash.com/photo-1709687626729-1e7d81cf13b3?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a woman standing on a beach next to the ocean",
    photographer: "Saman Tabrizy",
    username: "sam932",
    link: "https://unsplash.com/photos/a-woman-standing-on-a-beach-next-to-the-ocean-AGMz8Nbw4mw"
  },
  # Kids Hurricane Sandal
  "prod_1040" => %{
    url:
      "https://images.unsplash.com/photo-1621907014539-76bf9ebb6bca?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "woman in white and blue stripe skirt and white sandals",
    photographer: "vu khoi",
    username: "jinkazamah",
    link:
      "https://unsplash.com/photos/woman-in-white-and-blue-stripe-skirt-and-white-sandals-EpgQwXH3BJo"
  },
  # Bora Bora Booney Hat
  "prod_1041" => %{
    url:
      "https://images.unsplash.com/photo-1658498854739-05fb9bf00168?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a man wearing a hat",
    photographer: "Ray Shrewsberry",
    username: "ray12119",
    link: "https://unsplash.com/photos/a-man-wearing-a-hat-grpIu6VUYFI"
  },
  # Kids Bucket Hat
  "prod_1042" => %{
    url:
      "https://images.unsplash.com/photo-1559010012-ce7447422d91?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "woman sitting on looking her right side",
    photographer: "Xin",
    username: "s1n",
    link: "https://unsplash.com/photos/woman-sitting-on-looking-her-right-side-I7O5hE086q4"
  },
  # XX Chino Standard Taper
  "prod_1043" => %{
    url:
      "https://images.unsplash.com/photo-1619470148547-0adbfc64b595?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "person in blue long sleeve shirt and beige skirt",
    photographer: "Vlady Nykulyak",
    username: "vlad_nyk95",
    link:
      "https://unsplash.com/photos/person-in-blue-long-sleeve-shirt-and-beige-skirt-xbZdXJ4MFzg"
  },
  # Saturday Trail Pants
  "prod_1044" => %{
    url:
      "https://images.unsplash.com/photo-1717080988662-f809899862e1?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a person sitting on a rock near a lake",
    photographer: "Annie Spratt",
    username: "anniespratt",
    link: "https://unsplash.com/photos/a-person-sitting-on-a-rock-near-a-lake-5ZySRTL2gog"
  },
  # Palm Coast Linen Pants
  "prod_1045" => %{
    url:
      "https://images.unsplash.com/photo-1475699230575-2a5929c0ed72?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "woman sitting and leaning on wall",
    photographer: "Christopher Campbell",
    username: "chrisjoelcampbell",
    link: "https://unsplash.com/photos/woman-sitting-and-leaning-on-wall-_0PtmUlNqiY"
  },
  # Kids Silver Ridge Pull-On Pants
  "prod_1046" => %{
    url:
      "https://images.unsplash.com/photo-1551009007-b70dd044a923?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "man standing while holding bottle",
    photographer: "Simon Lund",
    username: "simonlundh",
    link: "https://unsplash.com/photos/man-standing-while-holding-bottle-ScmyRl3fOBE"
  },
  # Sunset Wrap Dress
  "prod_1047" => %{
    url:
      "https://images.unsplash.com/photo-1784549758741-7783a2eadc24?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "A young woman in a vibrant, colorful blazer and skirt",
    photographer: "Reza Roshan",
    username: "rezamr2",
    link:
      "https://unsplash.com/photos/a-young-woman-in-a-vibrant-colorful-blazer-and-skirt-ByR1F-uFrbE"
  },
  # Island Maxi Dress
  "prod_1048" => %{
    url:
      "https://images.unsplash.com/photo-1775688425791-fa21933857f3?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "Two women in striped traditional clothing stand together",
    photographer: "Oswald Elsaboath",
    username: "ozzzyphotos",
    link:
      "https://unsplash.com/photos/two-women-in-striped-traditional-clothing-stand-together-_qqJnyRNwXI"
  },
  # Sanibel Shirt Dress
  "prod_1049" => %{
    url:
      "https://images.unsplash.com/photo-1532383911524-17cd3daf08cb?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "woman leaning on red Volkswagen van",
    photographer: "Alora Griffiths",
    username: "aloragriffiths",
    link: "https://unsplash.com/photos/woman-leaning-on-red-volkswagen-van-Cc_ArxoAOAQ"
  },
  # Girls Twirl Dress
  "prod_1050" => %{
    url:
      "https://images.unsplash.com/photo-1635929326534-3e4d5917b6a5?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a little girl wearing a pink dress and a bow in her hair",
    photographer: "Mawabo Mazwi",
    username: "wabz_01",
    link:
      "https://unsplash.com/photos/a-little-girl-wearing-a-pink-dress-and-a-bow-in-her-hair-v3UHMNC2apc"
  },
  # Coastal Straw Hat
  "prod_1051" => %{
    url:
      "https://images.unsplash.com/photo-1787475532055-b3e5eda61fd8?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "A woman in a straw hat and white cover-up on a beach with white cliffs",
    photographer: "Konara Bandara",
    username: "kbandara",
    link: "https://unsplash.com/photos/woman-in-straw-hat-on-beach-xk8jvt5sYXI"
  },
  # Coolhead II Ball Cap
  "prod_1052" => %{
    url:
      "https://images.unsplash.com/photo-1691256676359-20e5c6d4bc92?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "a white baseball cap on a gray background",
    photographer: "personalgraphic.com",
    username: "personal_graphic",
    link: "https://unsplash.com/photos/a-white-baseball-cap-on-a-gray-background-ozdzzeBu4Go"
  },
  # Polarized Sunglasses
  "prod_1053" => %{
    url:
      "https://images.unsplash.com/photo-1572635196237-14b3f281503f?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "shallow focus photo of black Ray-Ban wayfarer sunglasses",
    photographer: "Giorgio Trovato",
    username: "giorgiotrovato",
    link:
      "https://unsplash.com/photos/shallow-focus-photo-of-black-ray-ban-wayfarer-sunglasses-K62u25Jk6vo"
  },
  # Kids Flexible Sunglasses
  "prod_1054" => %{
    url:
      "https://images.unsplash.com/photo-1599192756040-7a4a9af323c6?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "man in blue dress shirt and black pants riding red motorcycle",
    photographer: "julio andres rosario ortiz",
    username: "cocodrilomediard",
    link:
      "https://unsplash.com/photos/man-in-blue-dress-shirt-and-black-pants-riding-red-motorcycle-yuRAHZl3kXo"
  },
  # Atom Sling 8L
  "prod_1055" => %{
    url:
      "https://images.unsplash.com/photo-1751522949283-293763ee6f2a?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "A striped michael kors purse is pictured",
    photographer: "Fashion Needles",
    username: "fashionneedles",
    link: "https://unsplash.com/photos/a-striped-michael-kors-purse-is-pictured-v_praOEpVcI"
  },
  # Sand-Free Beach Tote
  "prod_1056" => %{
    url:
      "https://images.unsplash.com/photo-1561596266-33b279af0880?w=900&h=900&fit=crop&q=80&auto=format",
    alt: "white net bag",
    photographer: "S O C I A L . C U T",
    username: "socialcut",
    link: "https://unsplash.com/photos/white-net-bag-RBb-z4VN4o0"
  }
}
