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
  <Auth
    supabaseClient={supabase}
    providers={[]}
    theme = "dark"

    
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
            button: { background: 'orange', color: 'white' },
            anchor: { color: 'blue' }, }
        }
    }
  />
)

export default LoginUI ;