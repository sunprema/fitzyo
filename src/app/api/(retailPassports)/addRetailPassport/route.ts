import { NextResponse, NextRequest } from "next/server";
import { createServerComponentClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'
import { Database } from '@/types/supabase';

export async function POST(request:NextRequest){
    
    const supabase = createServerComponentClient<Database>({
        cookies,
    })
    
    const {
        data: { session },
    } = await supabase.auth.getSession()
    
    if (!session){
        return NextResponse.json( {"message" : "User Not found"} , {"status" : 400})
    }
    else {
    const req = await request.json()
    //get the nick_name from request, It will be used for the other call to insert into user_retail_passport_table

    const nick_name = req['nick_name']
    delete req['nick_name']

    let status = 400
    let response = {}
    console.log(JSON.stringify(req, null, 2))
    try{
        const dbInsertResponse = await supabase
        .from('men_retail_passport')
        .insert(req)
        .select()

        if( dbInsertResponse != null){
            const id = dbInsertResponse?.data?.at(0)?.id
            if (id != undefined){
               const userRetailPassportInsertResponse = await supabase
                .from('USER_RETAIL_PASSPORTS')
                .insert({retail_passport_id : id, nick_name })

               console.log(JSON.stringify(userRetailPassportInsertResponse, null, 2)) 
            response = userRetailPassportInsertResponse ;
            }
        }
        

        status = 200 ;

    }catch(error){
        status = 400
        response = {error}
    }
    finally{
        console.log(response)
        return NextResponse.json({response},{status: 200});
    }
    
    
    
    }
    
    

    
}