'use client';

import { useEffect } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Auth } from '@supabase/auth-ui-react';
import {
  // Import predefined theme
  ThemeSupa,
} from '@supabase/auth-ui-shared';


import { useConfig } from '@/components/configContext';
import BackButton from '@/components/backButton';

//const supabase = createClientComponentClient()

const SignInPage = () => {
  
  const router = useRouter();
  const config = useConfig();
  const supabase = config.supabase;

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session != null){
        config.setIsLoggedIn(true);
        router.push("/showRetailPassports")
      }

    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      if (_event === "SIGNED_OUT"){
        config.setIsLoggedIn(false)
      }
      if (_event === "SIGNED_IN"){
        if (session != null){
        config.setIsLoggedIn(true);
        router.push("/showRetailPassports")
        }
      }
    });

    return () => subscription.unsubscribe();
  }, [config, supabase, router]);

  
  return (
    <div className={'w-full'}>
      {/* Sign In Header */}
      <nav className={'items-center  py-6 shadow-md'}>
        <div className={'container mx-auto flex justify-between gap-3'}>
          <BackButton />

          <h4 className={'font-semibold'}> Sign in</h4>
          <Link
            href="/"
            className="font-sans text-xl font-bold tracking-wide subpixel-antialiased hover:font-extrabold"
          >
            {' '}
            <span className={'text-2xl'}>&#129434;</span> Fitzyo
          </Link>
        </div>
      </nav>

      {/* Auth Section */}
      <div className="container mx-auto my-10 max-w-md">
        {!config.isLoggedIn ? (
          <Auth
            supabaseClient={supabase}
            providers={[]}
            theme="dark"
            localization={{
              variables: {
                sign_in: {
                  email_label: 'Email Address:',
                  password_label: 'Password:',
                },
              },
            }}
            appearance={{
              theme: ThemeSupa,
              style: {
                button: { background: 'green', color: 'white' },
                anchor: { color: 'blue' },
              },
            }}
          />
        ) : null
      }
      </div>
    </div>
  );
};

export default SignInPage;
export const dynamic = 'force-dynamic';