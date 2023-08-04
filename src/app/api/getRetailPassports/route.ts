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
    console.log( req)
    return NextResponse.json({session});
    }
    
    

    
}