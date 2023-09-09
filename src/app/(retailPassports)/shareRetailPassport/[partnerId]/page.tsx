import { createServerComponentClient } from '@supabase/auth-helpers-nextjs';
import { cookies } from 'next/headers'
import { Database } from '@/types/supabase'

const Page = async ({params}:{"params" : {"partnerId":string}}) => {
    const {partnerId} = params ;
    const supabase = createServerComponentClient<Database>({
        cookies,
    })

    const {data:partners,error} = await 
        supabase
        .from("partners")
        .select("*")
        .filter("partner_id", "eq", partnerId)
    
    if(error){
        console.error(error)
        return(
            <div className={'container mx-auto'} >
                <h1> Unknown Retail Partner</h1>
                <pre>
                    This partner is not registered with Fitzyo.
                </pre>
            </div>
        )
    }
    if( partners?.length == 1 ){
        return(
            <div className={'container mx-auto'} >
                <h1> Do you want to share your retail passport with {partners[0].partner_name} ? </h1>
                
            </div>
        )

    }else{
        return(
            <div className={'container mx-auto'} >
                <h1> Unknown Retail Partner</h1>
                <pre>
                    This partner is not registered with Fitzyo.
                </pre>
            </div>
        )
    }    
}    


export default Page;