import { createServerComponentClient } from '@supabase/auth-helpers-nextjs';
import { cookies } from 'next/headers'
import { Database } from '@/types/supabase';

const Page = async ({params}:{ 'params':{'retailPassportId':string}}) => {
    const {retailPassportId}= params
    const supabase = createServerComponentClient<Database>({
        cookies,
    })
    const {
        data: { session },
      } = await supabase.auth.getSession();
    
    if (!session){
        return null;
    }
    try{
        const {data,error} = await supabase.from("men_retail_passport").select().eq("id", retailPassportId)
        return(
            <div className={'container mx-auto'} >
                <h1> Retail Passport {retailPassportId}</h1>
                <pre>
                    {JSON.stringify(data,null, 2)}
                </pre>
            </div>
        )

    }catch(error){
        console.log(error)
        return null ;
    }
    
    
    
}

export default Page ;