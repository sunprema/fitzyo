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
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}
