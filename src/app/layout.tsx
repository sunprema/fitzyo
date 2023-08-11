import './globals.css';

import { ThemeProvider } from '@/components/ui/theme-provider';
import { ConfigProvider } from '@/app/components/configContext';

import '@/app/globals.css';

import { fontSans } from '@/lib/fonts';
import { cn } from '@/lib/utils';
import { Metadata } from 'next';

export const metadata:Metadata = {
  title: 'Fitzyo',
  description: 'Measure once, buy anywhere.',
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: 'white' },
    { media: '(prefers-color-scheme: dark)', color: 'black' },
  ],
};


export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head />
      <body className={cn('min-h-screen bg-background font-sans antialiased', fontSans.variable)}>
        <ThemeProvider attribute="class" defaultTheme="system" enableSystem>
          <ConfigProvider>{children}</ConfigProvider>
        </ThemeProvider>
      </body>
    </html>
  );
}
