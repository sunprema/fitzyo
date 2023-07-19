import { NextResponse } from "next/server";

import { sleep } from "../utils/utilFunctions";



export async function POST(request){
    console.log(request)
    const req = await request.json()
    console.log( req)
    //process the request here

    await sleep(5000)

    const res = { req, 'Status': 'Success'}

    return NextResponse.json({res});
}