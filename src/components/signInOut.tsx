'use client'
import { User } from '@supabase/supabase-js'
import { Button } from './ui/button'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { useEffect, useState } from 'react'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'


const supabase = createClientComponentClient()



const SignInOutButton = () => {
    
    const [user, setUser] = useState<User | null>()
    const router = useRouter();
    
    useEffect(() => {

        const getUser = async() => {
            const { data: {user}} = await supabase.auth.getUser();
            setUser( user)
        }
        getUser()        
    },[])

    

    const handleSignOut = async () => {
        await supabase.auth.signOut();
        router.replace("/signIn")
    }
    let button = null ;
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