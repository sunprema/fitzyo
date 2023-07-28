'use client'
import { Auth } from '@supabase/auth-ui-react'
import { createClient } from '@supabase/supabase-js'
import {  
  ThemeSupa,
} from '@supabase/auth-ui-shared'

import {useState, useEffect } from 'react'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
)

const LoginUI = () => {
  const [session, setSession ] = useState(null)

  useEffect( () => {
    
    supabase.auth.getSession().then( ({data:{ session } }) => {
      setSession( session );
    } )

    const { data: {subscription} } = supabase.auth.onAuthStateChange( (_event, session) => {
      setSession(session);
    })
    
    return () => subscription.unsubscribe();

  },[])

  if (!session){
    return(
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
  }else{

    return (
      <div>
        <div>Logged in!</div>
        <button onClick={() => supabase.auth.signOut()}>Sign out</button>
      </div>
    );

  }

  

}

export default LoginUI ;