'use client';

import { createContext, ReactNode, useContext, useState } from 'react';
import { createClientComponentClient, SupabaseClient } from '@supabase/auth-helpers-nextjs';

import { Database } from '@/types/supabase';

const supabase = createClientComponentClient();

const notImplemented = () => {
  throw new Error('Not implemented');
};

export interface ConfigInterface {
  isLoggedIn: boolean;
  setIsLoggedIn: (loggedIn: boolean) => void;
  supabase: SupabaseClient<Database>;
}

const ConfigContext = createContext<ConfigInterface>({
  isLoggedIn: false,
  setIsLoggedIn: notImplemented,
  supabase: supabase,
});

export const useConfig = () => {
  return useContext(ConfigContext);
};

export const ConfigProvider = ({ children }: { children: ReactNode }) => {
  const [isLoggedIn, setIsLoggedIn] = useState<boolean>(false);
  const context: ConfigInterface = { isLoggedIn, setIsLoggedIn, supabase };

  return <ConfigContext.Provider value={context}>{children}</ConfigContext.Provider>;
};
