import { createServerComponentClient } from '@supabase/auth-helpers-nextjs';
import { cookies } from 'next/headers'
import { Database } from '@/types/supabase'
import MenForm, { MenFormSchema } from '../../addRetailPassport/[mode]/menRetailPassport';
import { Suspense } from 'react';
import LoadingSkeleton from './loading';


const ShowRetailPassportPage = async ({params}:{ 'params':{'retailPassportId':string}}) => {
    const {retailPassportId}= params
    const supabase = createServerComponentClient<Database>({
        cookies,
    })
    const {
        data: { session },
      } = await supabase.auth.getSession();

    let defaultValues:z.infer<typeof MenFormSchema> = null  
    
    if (!session){
        return null;
    }
    try{
        const { data, error } = await supabase
             .from('USER_RETAIL_PASSPORTS')
             .select("*")
             .eq("id", retailPassportId)

        if(error){
            console.log(error)
        }
        if(data){
            const {nick_name, retail_passport_id} = data[0]
            

            if(retail_passport_id !== null){
                const { data, error } = await supabase
                .from('men_retail_passport')
                .select("*")
                .eq("id", retail_passport_id)
                if(error){
                    console.log(error)
                }
                if(data){
                    defaultValues = data[0]
                    defaultValues['nick_name']= nick_name
                    console.log({defaultValues})
                }
            }
            


    }    
    }catch(error){
        console.log(error)
    }

    return (
        <div>
      <section className={'my-8 flex w-full flex-col items-center'}>
          <h1 className={'text-xl font-semibold leading-tight tracking-tighter md:text-2xl'}>
            Retail passport : id :{retailPassportId}
          </h1>
          
            <MenForm defaultValues={defaultValues}/>
          
      </section>    

    </div>
    )

}
export default ShowRetailPassportPage ;
export const dynamic = 'force-dynamic';