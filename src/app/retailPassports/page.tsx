
import { createServerComponentClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'

import { Database } from '@/types/supabase';

const RetailPassports = async () => {
    const supabase = createServerComponentClient<Database>({
        cookies,
    })
    const {
        data: { session },
    } = await supabase.auth.getSession()

    return (
        <>    
        <h1> Hello : </h1>
        <pre>
            {JSON.stringify(session, null , 2)}
        </pre>
        <h2> {session?.user.email}</h2>
        </>       

    )

}

export default RetailPassports ;