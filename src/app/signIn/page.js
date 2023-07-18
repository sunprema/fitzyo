'use client'

import { IconArrowLeft } from '@tabler/icons-react';
import Link from 'next/link';
import { Auth } from '@supabase/auth-ui-react'
import { createClient } from '@supabase/supabase-js'
import {
  // Import predefined theme
  ThemeSupa,
} from '@supabase/auth-ui-shared'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
)

const LoginUI = () => (
  
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
    </div>  

  </div>
)

export default LoginUI ;