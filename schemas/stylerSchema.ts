export interface StylerSuggestion {
    // Some tip about the suggestion below and the reasoning for the suggestion.
    summary: string;   
    
    garments: Garment[];
}

export interface Garment{
    
    // Category of the product like Shirt, Pant, Belt, Shoe, Saree,   undetermined should be categorized under Miscellaneous
    category: 'Shirts' | 'Pants' | 'Belt' | 'Hat' | 'Sun glasses' | 'Boot' | 'Shoes' | 'Trousers' | 'Saree' | 'Silk Saree' | 'Swim suit' | 'Miscellaneous';
    
    //short description of the category
    description: string;
    items : Item[];
}

export interface Item{
    // name of the product, like T-Shirts, Button up shirts, Jacket, Blazer etc.
    product : string;
    
    // short description of the product like why this is included in the result.
    description? : string;
    
    // Optional quantity based on user query.
    optionQuantity?: string;
}