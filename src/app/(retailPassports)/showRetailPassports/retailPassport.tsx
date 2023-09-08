'use client'

import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
    Card,
    CardContent,
    CardDescription,
    CardFooter,
    CardHeader,
    CardTitle,
 } from "@/components/ui/card"
import { Database } from '@/types/supabase';
import Link from "next/link";
 
function getRandomInt(max:number) {
  return Math.floor(Math.random() * max);
}

const alphaSizes = ["X", "XS", "M", "L", "XL" , "XXL"] 

 export default function RetailPassport({ 
    userRetailPassport 
}: {
    userRetailPassport: Database['public']['Tables']['USER_RETAIL_PASSPORTS']['Row']
    }){

    const handleShare = () => {
      const targetWindow = window.opener
      targetWindow.postMessage(
        {"retailPassportData": 
          {
            "name" : userRetailPassport.nick_name,
            "alphaSize" : alphaSizes[getRandomInt(6)],
            "numericalSize" : "36"        
          }
        }, 
        "*"); //todo: fix this
    }

    return (
    
    <Card className="group w-[350px] shadow-2xl border-orange-500 dark:shadow-orange-400 dark:border-orange-500 hover:border-orange-500 hover:shadow-orange-400">
      
      <CardHeader>
        <Link href={`/useRetailPassport/${userRetailPassport.id}`}> 
        <CardTitle>{userRetailPassport.nick_name}</CardTitle>
        <CardDescription>
            Retail passport created on 
            <Badge variant="secondary" className={'rounded-xl'}>{userRetailPassport.created_at}</Badge>
        </CardDescription>
        </Link>
        </CardHeader>
        <CardFooter>
        
        <div className="mt-8">
        <Button variant="secondary" className={'rounded-xl hover:bg-slate-600'} onClick={handleShare}>
          Share it with parner</Button>
        </div>
          
        </CardFooter>
      
      <CardContent>
      </CardContent>      
    </Card> 
        
    )

}