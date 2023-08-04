'use client'
import { Button } from '../../components/ui/button'
import Link from 'next/link'
import { useRouter } from 'next/navigation'
import { useConfig } from '@/app/components/configContext'

const SignInOutButton = () => {
    
    const router = useRouter();
    const config = useConfig();

    const handleSignOut = async () => {
        await config.supabase.auth.signOut();
        config.setIsLoggedIn(false);
        router.replace("/")
    }

    let button = null ;

    if (config.isLoggedIn ){
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