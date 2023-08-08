

import { Badge } from "@/components/ui/badge";
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
    userRetailPassport: Database['public']['Tables']['USER_RETAIL_PASSPORTS']['Row']
    }){
    return (
        
    <Card className="w-[350px]">
      <CardHeader>
        <CardTitle>{userRetailPassport.nick_name}</CardTitle>
        <CardDescription>
            Retail passport created on 
            <Badge variant="secondary" className={'rounded-sm'}>{userRetailPassport.created_at}</Badge>
        </CardDescription>
      </CardHeader>
      <CardContent>
      </CardContent>
      <CardFooter className="flex justify-between">
       
      </CardFooter>
    </Card>    

        
    )

}