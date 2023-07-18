'use client'
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
  <div className='container mx-auto my-10'>
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
)

export default LoginUI ;