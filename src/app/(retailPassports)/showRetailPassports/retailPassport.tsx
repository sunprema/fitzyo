

import {
    Card,
    CardContent,
    CardDescription,
    CardFooter,
    CardHeader,
    CardTitle,
 } from "@/components/ui/card"
 import { Database } from '@/types/supabase';

 export default function RetailPassport({ 
    userRetailPassport 
}: {
    userRetailPassport: Database['public']['Tables']['USER_RETAIL_PASSPORTS']['Row'] | null
    }){
    return (
        <h1>{userRetailPassport?.nick_name}</h1>
    )

}