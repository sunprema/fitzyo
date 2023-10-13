'use client'


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
import { useToast } from "./ui/use-toast";
import { Separator } from "./ui/separator";
import moment from "moment";
 
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
    
    const {toast}  = useToast()
    
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
        targetOrigin);
        toast({
          title: "Please go back to the partner website",
          description: `Your retail passport is shared with ${partner?.partner_name}`,
              
      })  

    },[partner?.partner_target_url, userRetailPassport.nick_name, toast, partner?.partner_name])

    return (
    
    <Card className="group w-[350px] border-orange-500 shadow-2xl hover:border-orange-500 hover:shadow-orange-400 dark:border-orange-500 dark:shadow-orange-400">
      
      <CardHeader>
        <Link href={`/showRetailPassport/${userRetailPassport.id}`}> 
        <CardTitle>{userRetailPassport.nick_name}</CardTitle>
        <Separator className="my-4" />

        <CardDescription>
          created at
          <h4 className="font-light text-xs">{`${moment(userRetailPassport.created_at).format("DD/MMM/YY")}`}</h4>
        </CardDescription>

        </Link>
        </CardHeader>
        <CardFooter>
        
        { 
        partner &&
        <div className="my-8">
        <Button variant="secondary" className={'rounded-xl text-sm hover:bg-slate-600'} onClick={handleShare}>
          {`Share it with ${partner.partner_name}`} </Button>
        </div>
        
        }

      <div className="my-2">
        <h4 className="text-xs font-extralight"> you used this at {Math.floor(Math.random() * 20)} retail sites!</h4>
      </div>
      </CardFooter>
      
      <CardContent>
      </CardContent>      
    </Card> 
        
    )

}