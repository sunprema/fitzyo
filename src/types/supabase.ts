export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      brand_product_categories: {
        Row: {
          brand_id: number | null
          created_at: string
          id: number
          product_category_id: number | null
        }
        Insert: {
          brand_id?: number | null
          created_at?: string
          id?: number
          product_category_id?: number | null
        }
        Update: {
          brand_id?: number | null
          created_at?: string
          id?: number
          product_category_id?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "brand_product_categories_brand_id_fkey"
            columns: ["brand_id"]
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "brand_product_categories_product_category_id_fkey"
            columns: ["product_category_id"]
            referencedRelation: "product_categories"
            referencedColumns: ["id"]
          }
        ]
      }
      brand_tops_size_chart: {
        Row: {
          alpha_size: string | null
          brand_id: number
          chest_high: number | null
          chest_low: number | null
          hip_high: number | null
          hip_low: number | null
          id: number
          neck_high: number | null
          neck_low: number | null
          numerical_size: number | null
          sleeve_high: number | null
          sleeve_low: number | null
        }
        Insert: {
          alpha_size?: string | null
          brand_id: number
          chest_high?: number | null
          chest_low?: number | null
          hip_high?: number | null
          hip_low?: number | null
          id?: number
          neck_high?: number | null
          neck_low?: number | null
          numerical_size?: number | null
          sleeve_high?: number | null
          sleeve_low?: number | null
        }
        Update: {
          alpha_size?: string | null
          brand_id?: number
          chest_high?: number | null
          chest_low?: number | null
          hip_high?: number | null
          hip_low?: number | null
          id?: number
          neck_high?: number | null
          neck_low?: number | null
          numerical_size?: number | null
          sleeve_high?: number | null
          sleeve_low?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "brand_tops_size_chart_brand_id_fkey"
            columns: ["brand_id"]
            referencedRelation: "brands"
            referencedColumns: ["id"]
          }
        ]
      }
      brands: {
        Row: {
          brand_name: string | null
          created_at: string
          description: string | null
          id: number
          website: string | null
        }
        Insert: {
          brand_name?: string | null
          created_at?: string
          description?: string | null
          id?: number
          website?: string | null
        }
        Update: {
          brand_name?: string | null
          created_at?: string
          description?: string | null
          id?: number
          website?: string | null
        }
        Relationships: []
      }
      FITZYO_ROLES: {
        Row: {
          created_at: string | null
          id: number
          role: string | null
        }
        Insert: {
          created_at?: string | null
          id?: number
          role?: string | null
        }
        Update: {
          created_at?: string | null
          id?: number
          role?: string | null
        }
        Relationships: []
      }
      men_retail_passport: {
        Row: {
          belt_length: number | null
          belt_waist_size: number | null
          glove_hand_circumference: number | null
          glove_hand_length: number | null
          id: number
          inserted_at: string
          measurement_date: string | null
          pant_hips: number | null
          pant_inseam: number | null
          pant_outseam: number | null
          pant_waist: number | null
          shirt_chest: number | null
          shirt_length: number | null
          shirt_neck: number | null
          shirt_sleeve_length: number | null
          shirt_waist: number | null
          shoe_arch_length: number | null
          shoe_foot_length: number | null
          shoe_foot_width: number | null
          updated_at: string
        }
        Insert: {
          belt_length?: number | null
          belt_waist_size?: number | null
          glove_hand_circumference?: number | null
          glove_hand_length?: number | null
          id?: number
          inserted_at?: string
          measurement_date?: string | null
          pant_hips?: number | null
          pant_inseam?: number | null
          pant_outseam?: number | null
          pant_waist?: number | null
          shirt_chest?: number | null
          shirt_length?: number | null
          shirt_neck?: number | null
          shirt_sleeve_length?: number | null
          shirt_waist?: number | null
          shoe_arch_length?: number | null
          shoe_foot_length?: number | null
          shoe_foot_width?: number | null
          updated_at?: string
        }
        Update: {
          belt_length?: number | null
          belt_waist_size?: number | null
          glove_hand_circumference?: number | null
          glove_hand_length?: number | null
          id?: number
          inserted_at?: string
          measurement_date?: string | null
          pant_hips?: number | null
          pant_inseam?: number | null
          pant_outseam?: number | null
          pant_waist?: number | null
          shirt_chest?: number | null
          shirt_length?: number | null
          shirt_neck?: number | null
          shirt_sleeve_length?: number | null
          shirt_waist?: number | null
          shoe_arch_length?: number | null
          shoe_foot_length?: number | null
          shoe_foot_width?: number | null
          updated_at?: string
        }
        Relationships: []
      }
      partners: {
        Row: {
          created_at: string
          partner_id: string
          partner_name: string
          partner_target_url: string
          website: string
        }
        Insert: {
          created_at?: string
          partner_id?: string
          partner_name: string
          partner_target_url: string
          website: string
        }
        Update: {
          created_at?: string
          partner_id?: string
          partner_name?: string
          partner_target_url?: string
          website?: string
        }
        Relationships: []
      }
      product_categories: {
        Row: {
          category: string | null
          description: string | null
          id: number
        }
        Insert: {
          category?: string | null
          description?: string | null
          id?: number
        }
        Update: {
          category?: string | null
          description?: string | null
          id?: number
        }
        Relationships: []
      }
      USER_RETAIL_PASSPORTS: {
        Row: {
          created_at: string | null
          id: number
          nick_name: string | null
          retail_passport_id: number | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: number
          nick_name?: string | null
          retail_passport_id?: number | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: number
          nick_name?: string | null
          retail_passport_id?: number | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "USER_RETAIL_PASSPORTS_retail_passport_id_fkey"
            columns: ["retail_passport_id"]
            referencedRelation: "men_retail_passport"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "USER_RETAIL_PASSPORTS_user_id_fkey"
            columns: ["user_id"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
      USER_ROLE: {
        Row: {
          created_at: string | null
          id: number
          role_id: number | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          id?: number
          role_id?: number | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          id?: number
          role_id?: number | null
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "USER_ROLE_role_id_fkey"
            columns: ["role_id"]
            referencedRelation: "FITZYO_ROLES"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "USER_ROLE_user_id_fkey"
            columns: ["user_id"]
            referencedRelation: "users"
            referencedColumns: ["id"]
          }
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      mens_tops_brands_size: {
        Args: {
          retail_passport_id_input: number
        }
        Returns: {
          brand_id: number
          brand_name: string
          brand_website: string
          brand_description: string
          alpha_size: string
          numerical_size: number
        }[]
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}
