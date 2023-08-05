import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

import { createMiddlewareClient } from '@supabase/auth-helpers-nextjs'

import type { Database } from './types/supabase';

export async function middleware(req: NextRequest) {
  const res = NextResponse.next()
  const supabase = createMiddlewareClient<Database>({ req, res })
  const {data : {session}} = await supabase.auth.getSession()
  if (!session){
    return NextResponse.redirect(new URL('/signIn', req.url))        
  }else{
    return res
  }
  
}

export const config = {
    matcher : ['/userHome','/retailPassports', '/admin', '/api/:path*'],
};