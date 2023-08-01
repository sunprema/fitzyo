'use client'
import { createClient } from '@supabase/supabase-js'
import { Button } from './ui/button'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { useEffect, useState } from 'react'


const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
)



const SignInOutButton = (props:any) => {
    
    const [user, setUser] = useState(null)
    const router = useRouter();

    useEffect(() => {
        const {data: authListener} = supabase.auth.onAuthStateChange(
            async( event, session) => {
                if ( event === 'SIGNED_IN'){
                    setUser(session.user)
                }else if (event === 'SIGNED_OUT'){
                    setUser(null)
                }
            }
        )

        return () => {
            authListener.subscription.unsubscribe()
        }
    },[])

    

    const handleSignOut = async () => {
        await supabase.auth.signOut();
        router.refresh()
    }
    var button = null ;
    if (user != null ){
        button = <Button onClick={ handleSignOut }> Sign out 
        </Button>
    }else{
        button = <Button asChild>
              <Link href='/signIn'>
              Sign In
              </Link>
        </Button>
    }

    return button
    
}

export default SignInOutButton ;