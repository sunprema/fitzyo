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
import { useCallback } from "react";
 
function getRandomInt(max:number) {
  return Math.floor(Math.random() * max);
}

const alphaSizes = ["X", "XS", "M", "L", "XL" , "XXL"] 

 export default function RetailPassportCard({
    partner, 
    userRetailPassport 
}: {
    partner?:Database['public']['Tables']['partners']['Row']
    userRetailPassport: Database['public']['Tables']['USER_RETAIL_PASSPORTS']['Row']
    }){

    const handleShare = useCallback(() => {
      const targetOrigin = process.env.NODE_ENV != "production" ? "http://localhost:3001" :  partner?.partner_target_url
      const targetWindow = window.opener
      targetWindow.postMessage(
        {"retailPassportData": 
          {
            "name" : userRetailPassport.nick_name,
            "alphaSize" : alphaSizes[getRandomInt(6)],
            "numericalSize" : "36"        
          }
        }, 
        targetOrigin); //todo: fix this
    },[partner?.partner_target_url, userRetailPassport.nick_name])

    return (
    
    <Card className="group w-[350px] border-orange-500 shadow-2xl hover:border-orange-500 hover:shadow-orange-400 dark:border-orange-500 dark:shadow-orange-400">
      
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
        
        { 
        partner &&
        <div className="mt-8">
        <Button variant="secondary" className={'rounded-xl text-sm hover:bg-slate-600'} onClick={handleShare}>
          {`Share it with ${partner.partner_name}`} </Button>
        </div>
        }  
        </CardFooter>
      
      <CardContent>
      </CardContent>      
    </Card> 
        
    )

}