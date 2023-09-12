import { createServerComponentClient } from '@supabase/auth-helpers-nextjs';
import { cookies } from 'next/headers'
import { Database } from '@/types/supabase'
import Image from 'next/image'
import { redirect } from 'next/navigation';
import { RedirectType } from 'next/dist/client/components/redirect';
import RetailPassport from '../../../../components/retailPassport';



import {
  Alert,
  AlertDescription,
  AlertTitle,
} from "@/components/ui/alert"
import { AlertTriangle } from 'lucide-react';


const Page = async ({params}:{"params" : {"partnerId":string}}) => {
    const {partnerId} = params ;
    const supabase = createServerComponentClient<Database>({
        cookies,
    })

    
    let retailPassports = null ;

    const {data:partners,error} = await 
        supabase
        .from("partners")
        .select("*")
        .filter("partner_id", "eq", partnerId)
    
    if(error){
        console.error(error)
        return(
            <div className={'container mx-auto mt-32'} >
             <Alert variant="destructive">
                <AlertTriangle className="h-6 w-6" strokeWidth={3.25} />
                <AlertTitle>Invalid Partner ID!</AlertTitle>
                <AlertDescription>
                    This partner is not registered with Fitzyo.
                </AlertDescription>
            </Alert>
            <h1 className="border-b-2 border-orange-500 p-4 text-2xl font-medium">
            This partner is not registered with Fitzyo.
            </h1>
            <p className="mt-4 text-2xl font-light">
            Do not proceeed. Please close the window.
            </p>
            </div>
        )
    }
    if( partners?.length == 1 ){
        //there are two possibilities here, 1. User is already logged in, we can check User session and show retail passports. Or redirect to Sign In page, and on signIn, redirect back to this page.    
        // handle user not signed in
        const partner = partners[0]
        const {
            data: { session },
        } = await supabase.auth.getSession();

        if(session == null ){
            redirect(`/signInForPartner/${partnerId}`, RedirectType.push);
        }else{
            const { data: USER_RETAIL_PASSPORTS, error }= await supabase
                    .from('USER_RETAIL_PASSPORTS')
                    .select("*")

            if(error == null){
                retailPassports = USER_RETAIL_PASSPORTS
                return (
                    <div>
                        {retailPassports?.length  && retailPassports.length > 0 
                        ?
                        <div  className={'container mx-auto mt-16 flex flex-wrap gap-8'}>
                        {retailPassports?.map( 
                            (retailPassport) =>
                            
                            <RetailPassport 
                                key={retailPassport.id}
                                partner = {partner}
                                userRetailPassport={retailPassport} />
                            )
                        }
                        </div>
                        :
                        <div className="container mx-auto mt-20 w-[800px]">
                            <h4 className="px-12 pb-12 text-lg font-medium">No Retail passports available to share.</h4>  
                            <Image src="./images/welcome_cats.svg"
                            alt="No retail passports to share" 
                            width={600} height={400} />
                        </div> 
                        }
                    </div>
                )
            }else{
                console.log(error)
                return(
                    <h4> Error while getting Retail passports for user.</h4>
                )
            }        
        }
        

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

export const dynamic = 'force-dynamic';
export default Page;