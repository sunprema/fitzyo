'use client'

import { IconArrowLeft } from '@tabler/icons-react';
import Link from 'next/link';
import { Auth } from '@supabase/auth-ui-react'
import { createClient } from '@supabase/supabase-js'
import type { Session } from '@supabase/supabase-js';
import {
  // Import predefined theme
  ThemeSupa,
} from '@supabase/auth-ui-shared'


import {useState, useEffect } from 'react'
import { useRouter } from 'next/navigation';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL ?? "",
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? ""
)


const SignInPage = () => {
  const [session, setSession ] = useState<Session | null>(null)
  const router = useRouter()

  useEffect( () => {
    
    supabase.auth.getSession().then( ({data:{ session } }) => {
      setSession( session );
    } )

    const { data: {subscription} } = supabase.auth.onAuthStateChange( (_event, session) => {
      setSession(session);
    })
    
    return () => subscription.unsubscribe();

  },[])

  if ( session != null ){
    router.push('/userHome')
  }
  return (

    <div className={'w-full'}>

    {/* Sign In Header */}
    <nav className={'py-6  shadow-md items-center'}>
    
    <div className={'container mx-auto flex justify-between gap-3'}>
      <div className={'rounded-full p-1 bg-slate-100 hover:bg-slate-200'}>
      <Link href="/"><IconArrowLeft /> </Link>     
      </div>

      <h4 className={'font-semibold'}> Sign in</h4>
      <Link href="/" className='text-xl font-bold tracking-wide font-sans subpixel-antialiased hover:font-extrabold'> <span className={'text-2xl'}>&#129434;</span> Fitzyo</Link>      
    </div>

    </nav>

  
    {/* Auth Section */}
    <div className='container mx-auto my-10 max-w-md'>

      { session === null ? 
        <Auth
        supabaseClient={supabase}
        providers={[]}
        theme = "light"
        
        localization={{
            variables: {
              sign_in: {
                email_label: 'Email Address:',
                password_label: 'Password:',
              },
            },
          }}    
        appearance={{ theme: ThemeSupa , 
            style: {
                button: { background: 'green', color: 'white' },
                anchor: { color: 'blue' }, }
            }
        }
        />
       : 

      <div>
        <div>Logged in!</div>
        <button onClick={() => supabase.auth.signOut()}>Sign out</button>
        <p><pre>
          { JSON.stringify( session, null, 2) }

        </pre>
        </p>

      </div>
    

      }

    </div>  

    </div>
  )

  
}


export default SignInPage