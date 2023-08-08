'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { Auth } from '@supabase/auth-ui-react';
import {
  // Import predefined theme
  ThemeSupa,
} from '@supabase/auth-ui-shared';
import type { Session } from '@supabase/supabase-js';

import { useConfig } from '../components/configContext';
import BackButton from '../components/backButton';

//const supabase = createClientComponentClient()

const SignInPage = () => {
  const [session, setSession] = useState<Session | null>(null);
  const router = useRouter();
  const config = useConfig();
  const supabase = config.supabase;

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      config.setIsLoggedIn(true);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
    });

    return () => subscription.unsubscribe();
  }, [config, supabase]);

  if (session != null) {
    router.replace('/userHome');
  }
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
        {session === null ? (
          <Auth
            supabaseClient={supabase}
            providers={[]}
            theme="light"
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
        ) : (
          <div>
            <div>Logged in!</div>
            <button onClick={() => supabase.auth.signOut()}>Sign out</button>
            <p>
              <pre>{JSON.stringify(session, null, 2)}</pre>
            </p>
          </div>
        )}
      </div>
    </div>
  );
};

export default SignInPage;
