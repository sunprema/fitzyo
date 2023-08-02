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
      retail_passport: {
        Row: {
          created_at: string
          id: string
          inseam: string | null
          shoe_size: string | null
          user_id: string
          waist: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          inseam?: string | null
          shoe_size?: string | null
          user_id: string
          waist?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          inseam?: string | null
          shoe_size?: string | null
          user_id?: string
          waist?: string | null
        }
        Relationships: []
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
