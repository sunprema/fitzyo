'use client';

import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Auth } from '@supabase/auth-ui-react';
import {
  // Import predefined theme
  ThemeSupa,
} from '@supabase/auth-ui-shared';
import type { Session } from '@supabase/supabase-js';

import { useConfig } from '@/components/configContext';

//const supabase = createClientComponentClient()

const SignInForPartnerPage = ({params}:{"params" : {"partnerId":string}}) => {
  const [session, setSession] = useState<Session | null>(null);
  const router = useRouter();
  const config = useConfig();
  const supabase = config.supabase;
  const {partnerId} = params;

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      if (session?.user){
        setSession(session);
        config.setIsLoggedIn(true);
      }
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
    });
    
    return () => subscription.unsubscribe();
  }, [config, supabase])

  useEffect(()=>{
    if (config.isLoggedIn) {
        router.replace(`/shareRetailPassport/${partnerId}`);
    }
  }, [config.isLoggedIn, partnerId, router])

  
  return (
    <div className={'w-full'}>
      {/* Auth Section */}
      <div className="container mx-auto my-10 max-w-md">
        {session === null ? (
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

export default SignInForPartnerPage;
export const dynamic = 'force-dynamic';