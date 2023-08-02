import './globals.css'
import { ThemeProvider } from '@/components/ui/theme-provider'

import { Inter } from 'next/font/google'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: 'Fitzyo',
  description: 'Measure once, buy anywhere.',
}

export default function RootLayout({ children, } : { children : React.ReactNode}) {
  return (
    <html lang="en">
      <body className={inter.className} suppressHydrationWarning>
      <ThemeProvider attribute='class' defaultTheme='system' enableSystem>      
        {children}
      </ThemeProvider>       
      </body>
    </html>
  )
}
