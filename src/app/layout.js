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
      <body className={`flex min-h-screen flex-col ${inter.className}`}>
        <div className='bg-white  shrink w-full p-4 flex justify-between items-center ' >
          <Link href="/" className='text-xl font-bold tracking-wide font-sans subpixel-antialiased hover:font-extrabold'> Fitzyo</Link>
          <Link href="/aboutUs"> About us</Link>
        </div>
        {children}
        
      </body>
    </html>
  )
}
