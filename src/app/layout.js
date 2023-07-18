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
        
        {/* Header */}
        <header className='relative top-0 left-0 right-0 z-10 shadow-md'>
          <nav className=" py-6 flex justify-between items-center container mx-auto" >
            <Link href="/" className='text-xl font-bold tracking-wide font-sans subpixel-antialiased hover:font-extrabold'> <span className={'text-2xl'}>&#129434;</span> Fitzyo</Link>
            <div className={'flex justify-between space-x-20'} >
              <Link className='py-1 hover:text-green-400' href="/aboutUs" > About us</Link>
              <Link href='/signIn'>
              <div className='bg-green-600 shadow-md py-1 px-2 rounded-sm text-sm text-white font-sans font-semibold hover:bg-green-400'>
                Sign In
              </div>
              </Link>
            </div>  
          </nav>          
        </header>
        {children}
       
      </body>
    </html>
  )
}
