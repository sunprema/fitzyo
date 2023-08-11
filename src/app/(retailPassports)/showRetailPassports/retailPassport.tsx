

import { Badge } from "@/components/ui/badge";
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
 } from "@/components/ui/card"
 import { Database } from '@/types/supabase';
import Link from "next/link";
 


 export default function RetailPassport({ 
    userRetailPassport 
}: {
    userRetailPassport: Database['public']['Tables']['USER_RETAIL_PASSPORTS']['Row']
    }){

    

    return (
    <Link href={`/useRetailPassport/${userRetailPassport.id}`}>    
    <Card className="w-[350px]">
      <CardHeader>
        <CardTitle>{userRetailPassport.nick_name}</CardTitle>
        <CardDescription>
            Retail passport created on 
            <Badge variant="secondary" className={'rounded-xl'}>{userRetailPassport.created_at}</Badge>
        </CardDescription>
      </CardHeader>
      <CardContent>
      </CardContent>      
    </Card>    
    </Link>
        
    )

}