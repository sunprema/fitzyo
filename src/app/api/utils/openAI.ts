
import fs from "fs"
import path from "path"

import { StylerSuggestion } from "../../../../schemas/stylerSchema";

import { createJsonTranslator, processRequests , createOpenAILanguageModel} from "typechat";

//USING TYPECHAT TO DEAL WITH OPENAI
let typeChatModel = createOpenAILanguageModel( process.env.AI_STYLER_KEY,"gpt-3.5-turbo" );
const schema = fs.readFileSync(path.join(process.cwd(), "/schemas/stylerSchema.ts"), "utf8");
const translator = createJsonTranslator<StylerSuggestion>(typeChatModel, schema, "StylerSuggestion");


const modelPrompts = {
    'zebra' : ' formal wears, shoes, tie, belts ',
    'peacock' : ' ethnic wears sarees, salwar, chudidhar, kimono',
    'leopard' : ' sports wears, swim suits, watches',
    'lion' : ' all garments and latest fashion and dress trends '
}


const getSuggestionsFromChatGpt = async ( modelName:string, searchText:string ) => {
    const openAIPrompt = `system:You are a fashion designer specialized in ${ modelPrompts[modelName]}. Your task is to find garments for the user query following, user:${searchText}`
    console.log(`THE PROMPT IS : ${openAIPrompt}` );
    const start = Date.now();
    const response = await translator.translate(searchText);
    const end = Date.now();
    console.log(`Execution time: ${end - start} ms`);

    console.log(response);
    if (!response.success) {
        
        return "Couldnt get a proper response";
    }
    
   console.log(JSON.stringify(response.data))
   return response.data
}

export { getSuggestionsFromChatGpt }




