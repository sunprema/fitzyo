import { NextResponse } from "next/server";
import { getSuggestionsFromChatGpt } from "../../utils/openAI";
import type { NextRequest } from "next/server";




export  async function POST( request:NextRequest ){

    console.log(request)
    const req = await request.json()
    console.log( req)
    //process the request here , request will have the modelName & the searchText
    const { modelName, searchText } = req
    console.log(`SERVER: ${searchText}`) 
    
    //await sleep(1000)
    const chatGPTResponse = await getSuggestionsFromChatGpt( modelName, searchText)
    console.log(chatGPTResponse)
    
    return NextResponse.json( chatGPTResponse);
    

}