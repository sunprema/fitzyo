export const BRANDS = ["Columbia", "Patagonia", "Levi's", "Nike", "Adidas"];
export const COLORS = ["black", "white", "navy", "gray", "blue", "red", "green"];
export const FITS = ["slim", "regular", "relaxed", "oversized"];
export const ACTIVITIES = ["travel", "beach", "hiking", "casual", "dinner", "outdoor", "running"];
export const CATEGORIES = ["shirts", "pants", "shoes", "outerwear"];
export const CATEGORY_LABELS = { shirts: "Shirts", pants: "Pants", shoes: "Shoes", outerwear: "Outerwear" };
export const SIZES_BY_CATEGORY = {
  shirts: ["15/33", "15.5/34", "16/34", "16.5/34", "17/34", "17.5/35"],
  pants: ["30x30", "30x32", "32x32", "32x34", "34x32", "34x34", "36x32", "36x34"],
  shoes: ["8", "9", "9.5", "10", "10.5", "11", "11.5", "12"],
  outerwear: ["S", "M", "L", "XL", "XXL"]
};

export const DAD_PROFILE = {
  label: "Dad",
  shirtSize: "16.5/34",
  pantsSize: "34x32",
  shoeSize: "11",
  outerwearSize: "L",
  colors: ["navy", "gray"],
  brands: ["Columbia", "Patagonia"],
  style: "casual",
  maxPrice: 70
};

function pick(arr, i) { return arr[i % arr.length]; }
function sizeFor(cat, i) { const s = SIZES_BY_CATEGORY[cat]; return s.slice(0, 3 + (i % 3)).map((_, k) => s[(i + k) % s.length]); }

const SHIRT_NAMES = ["Performance Polo", "Coastal Linen Shirt", "Everyday Flannel", "Breeze Short-Sleeve", "Heritage Oxford", "Trailhead Henley", "Palm Grove Camp Shirt", "Voyager Button-Down", "Sunset Poplin Shirt", "Basecamp Flannel", "Riverside Chambray", "Harbor Stripe Tee-Shirt"];
const PANTS_NAMES = ["Trailblazer Chino", "Classic Straight Denim", "Weekend Jogger Pant", "Ridge Hiking Pant", "Everyday Twill Trouser", "Motion Stretch Chino", "Coastal Linen Pant", "Summit Cargo Pant", "Relaxed Taper Denim", "Traveler Comfort Pant"];
const SHOES_NAMES = ["Trailhead Runner", "Harbor Boat Shoe", "Everyday Court Sneaker", "Coastal Slide Sandal", "Ridge Hiking Shoe", "Downtown Canvas Sneaker", "Voyager Loafer", "Summit Trail Sandal"];
const OUTER_NAMES = ["Windward Packable Jacket", "Basecamp Fleece", "Coastal Rain Shell", "Heritage Denim Jacket", "Trailhead Softshell", "Harbor Bomber", "Summit Insulated Vest", "Voyager Travel Blazer", "Ridge Anorak", "Palm Breeze Overshirt"];

const MATERIALS = ["lightweight polyester", "brushed cotton", "organic cotton", "recycled nylon", "stretch cotton twill", "merino blend", "ripstop nylon", "linen blend"];

function build(cat, names) {
  return names.map((title, i) => {
    const brand = pick(BRANDS, i);
    const fit = pick(FITS, i + 1);
    const activities = [pick(ACTIVITIES, i), pick(ACTIVITIES, i + 3)];
    const colors = [pick(COLORS, i), pick(COLORS, i + 2), pick(COLORS, i + 4)].filter((c, idx, a) => a.indexOf(c) === idx);
    const basePrice = cat === "shoes" ? 65 : cat === "outerwear" ? 90 : cat === "pants" ? 60 : 45;
    const price = Math.round((basePrice + (i % 5) * 7 + (brand === "Patagonia" ? 15 : brand === "Columbia" ? 5 : 0)) - 0.01);
    return {
      id: `prod_${cat}_${i + 1}`,
      title,
      brand,
      category: cat,
      price: price + 0.99,
      currency: "USD",
      gender: "men",
      fit,
      material: pick(MATERIALS, i + 1),
      colors,
      sizes: sizeFor(cat, i),
      activities,
      description: `${title} in a ${fit} fit, crafted from ${pick(MATERIALS, i + 1)}. Built for ${activities.join(" and ")}.`,
      unavailableSizes: i % 7 === 0 ? [sizeFor(cat, i)[0]] : []
    };
  });
}

export const PRODUCTS = [
  ...build("shirts", SHIRT_NAMES),
  ...build("pants", PANTS_NAMES),
  ...build("shoes", SHOES_NAMES),
  ...build("outerwear", OUTER_NAMES)
];

// Guarantee a handful of clean "Dad matches": Columbia/Patagonia, navy or gray, 16.5/34, under $70
PRODUCTS[0].brand = "Columbia"; PRODUCTS[0].colors = ["navy", "gray", "white"]; PRODUCTS[0].sizes = ["16/34", "16.5/34", "17/34"]; PRODUCTS[0].price = 49.99; PRODUCTS[0].fit = "regular"; PRODUCTS[0].unavailableSizes = [];
PRODUCTS[4].brand = "Patagonia"; PRODUCTS[4].colors = ["navy", "gray"]; PRODUCTS[4].sizes = ["16/34", "16.5/34", "17/34"]; PRODUCTS[4].price = 64.0; PRODUCTS[4].fit = "regular"; PRODUCTS[4].unavailableSizes = [];
PRODUCTS[6].brand = "Columbia"; PRODUCTS[6].colors = ["navy", "green"]; PRODUCTS[6].sizes = ["16.5/34", "17/34"]; PRODUCTS[6].price = 55.5; PRODUCTS[6].fit = "regular"; PRODUCTS[6].unavailableSizes = [];

export function fitPriceOf(product) { return `$${product.price.toFixed(2)}`; }

export function sizeGuide(category) {
  if (category === "shirts") return { headers: ["Size", "Chest", "Neck", "Sleeve"], rows: [["15/33", "38–40\"", "15\"", "33\""], ["15.5/34", "40–42\"", "15.5\"", "34\""], ["16/34", "40–42\"", "16\"", "34\""], ["16.5/34", "42–44\"", "16.5\"", "34\""], ["17/34", "44–46\"", "17\"", "34\""], ["17.5/35", "46–48\"", "17.5\"", "35\""]] };
  if (category === "pants") return { headers: ["Size", "Waist", "Inseam"], rows: SIZES_BY_CATEGORY.pants.map(s => { const [w, i] = s.split("x"); return [s, `${w}"`, `${i}"`]; }) };
  if (category === "shoes") return { headers: ["US Size", "Foot Length"], rows: SIZES_BY_CATEGORY.shoes.map(s => [s, `${(9.5 + parseFloat(s) * 0.3).toFixed(1)}"`]) };
  return { headers: ["Size", "Chest"], rows: [["S", "36–38\""], ["M", "38–40\""], ["L", "40–42\""], ["XL", "42–44\""], ["XXL", "44–46\""]] };
}
