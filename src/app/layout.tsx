import './globals.css'
import { ThemeProvider } from '@/components/ui/theme-provider'
import { ConfigProvider } from '@/app/components/configContext'
import { Inter } from 'next/font/google'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: 'Fitzyo',
  description: 'Measure once, buy anywhere.',
}

export default function RootLayout({ children, } : { children : React.ReactNode}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head/>
      <body className={inter.className} >

      <ThemeProvider attribute='class' defaultTheme='system' enableSystem>      
        <ConfigProvider>
        {children}
        </ConfigProvider>
      </ThemeProvider>       
      </body>
    </html>
  )
}
