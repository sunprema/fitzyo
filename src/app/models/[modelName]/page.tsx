'use client'
import { IconArrowLeft, IconCircleArrowRightFilled } from '@tabler/icons-react'
import Link from 'next/link'
import React, { useState, useRef } from 'react'
import axios from 'axios'
import useSWR, { SWRConfig } from 'swr'
import { StylerSuggestion } from '../../../../schemas/stylerSchema'


const AI_STYLERS :{[key:string] : string} = {'zebra' : '🦓',
 'peacock' : '🦚' , 
 'lion': '🦁',
 'leopard': '🐆',}

interface SuggestionRequest {
    modelName : string;
    searchText: string;
}

const fetcher = async (suggestionRequestData:SuggestionRequest) => {
    console.log( suggestionRequestData)
    const response = await axios.post('/api/models/suggestions', suggestionRequestData , {'timeout' : 15000})
    return response.data    
    
}


const useSearchSuggestionHook = (suggestionRequest:SuggestionRequest) => {
    console.log(" useSearchSuggestionHook used here!")
    const {data, error, isLoading} = useSWR<StylerSuggestion,Error>( suggestionRequest, fetcher);
    return{
        data,
        error,
        isLoading
    }
}

const SearchSuggestionUI = ({suggestionRequest}:{suggestionRequest:SuggestionRequest})=> {
    const { data, error, isLoading} = useSearchSuggestionHook( suggestionRequest)
    let returnElement = <h1>Loading...</h1>
    if (isLoading) returnElement = <h1>Loading...</h1>
    if (error) returnElement = <h1> {` Error : ${error}`}</h1>
    if(data) returnElement = <p><pre>{ JSON.stringify(data, null, 2) }</pre></p>
        
    return returnElement
     
    

}

const placeholderTexts:{[key:string]:string} = {
    'zebra' :   'Help me pack for a business event in Japan in february',
    'peacock':  'planning to attend a Indian wedding, suggest me what should I wear',
    'leopard':  'Going for a scuba diving in Andaman, help me pack',
    'lion' : 'I am planning for a Hawaii trip in October, suggest me what I need to pack.'

}

const AIStylerUI = ({modelName}:{modelName:string}) => {
    
    const [searchText, setSearchText] = useState(placeholderTexts[modelName]); //TODO: remove the hardcoded searchText
    const [suggestionRequest, setSuggestionRequest] = useState<SuggestionRequest>({'modelName':"", searchText: ""});
    const inputRef = useRef(null)    

    
    
    


    const handleSearchText = () =>{
        alert(searchText)
        setSuggestionRequest({ modelName, searchText })
    }

    
    
   return (
    //First display the header, It should also have the styler name & emoji     
    <div className={'w-full'}>
    {/*Header */}
    <nav className={'py-6  shadow-md items-center'}>
    <div className={'container mx-auto flex justify-between gap-3'}>
      <div className={'rounded-full p-1 bg-slate-100 hover:bg-slate-200'}>
      <Link href="/"><IconArrowLeft /> </Link>     
      </div>

      <h4 className={'font-semibold'}> AI Styler </h4>
      <Link href="/" className='text-xl font-bold tracking-wide font-sans subpixel-antialiased hover:font-extrabold'> <span className={'text-2xl'}>&#129434;</span> Fitzyo</Link>      
    </div>
    </nav>

    {/* Display the emoji and the character */}
    <div className={'container mx-auto bg-white shadow-md rounded-md p-12 mt-12'}>
        
        {/* Emoji and the description */}
        <div className={'flex align-top items-center justify-evenly'}>
            <div className={'text-9xl text-center '}>
                {AI_STYLERS[modelName]}
            </div>
            <div className={'text-left'}>
                <h2 className={'font-bold'}>{modelName}</h2>
                <h6 className={'font-semibold'}> Trendy desciption of {modelName}</h6>
            </div>
        </div>

        {/* search box */}    
        <div className={'flex flex-col'}>
        
            <label className={'font-extrabold py-8'}>
                Lets shop! 
                <span className={'font-normal ml-4'}> What are we shopping?!</span>
            </label>
            
            <div className={`flex p-2 bg-slate-300  py-4 rounded-lg pl-10 border-solid border-gray-800`
                        }>
                <input type="text"
                    ref={inputRef}
                    value={searchText}
                    onChange={ (e) => setSearchText(e.target.value)}
                    placeholder={placeholderTexts[modelName]}
                    className={'w-full  bg-slate-300 focus:outline-none focus:border-blue-500 focus:text-gray-900 '} />
                
                <IconCircleArrowRightFilled 
                    size={'48'}
                    stroke='green' 
                    color='green' 
                    className={'flex-shrink-0 py-2 rounded-full hover:cursor-pointer hover:bg-green-500 focus:bg-green-500'} 
                    onClick = {handleSearchText}
                />        
            </div>

        </div> 

        <div> 
            <SWRConfig value={{
                revalidateIfStale : false,
                revalidateOnMount : false,
                revalidateOnFocus: false,
                revalidateOnReconnect : false,
                shouldRetryOnError : false,
            }}>               
                <SearchSuggestionUI suggestionRequest={suggestionRequest}/>
            </SWRConfig>
        </div>

        </div>

    </div>



  
   )

}


const AIModel = ({params}:{params:{'modelName':string}}) => {
    
    if( params.modelName in AI_STYLERS ){
        return (<AIStylerUI modelName={params.modelName} />)
    }else{
        throw new Error(`Model name ${params.modelName} is not valid`);
    }
    
}

export default AIModel ;