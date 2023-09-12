'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { Auth } from '@supabase/auth-ui-react';
import {
  // Import predefined theme
  ThemeSupa,
} from '@supabase/auth-ui-shared';


import { useConfig } from '@/components/configContext';

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
