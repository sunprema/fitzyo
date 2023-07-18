import './globals.css'
import { Inter } from 'next/font/google'
import Link from 'next/link'

const inter = Inter({ subsets: ['latin'] })

export const metadata = {
  title: 'Fitzyo',
  description: 'Measure once, buy anywhere.',
}

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body className={`${inter.className}`}>
        
        {/* Header - should be moved inside page*/}
        
        {children}
       
      </body>
    </html>
  )
}
