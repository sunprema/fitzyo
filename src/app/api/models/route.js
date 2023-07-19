import { NextResponse } from "next/server";


const sleep = ms => new Promise(r => setTimeout(r, ms));

export  async function GET(){

    let data = ["lion", "peacock", "zebra", "leopard"]
    await sleep(5000);
    
    return NextResponse.json(data);

}