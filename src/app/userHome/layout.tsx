
import { IconArrowLeft } from '@tabler/icons-react';
import Link from 'next/link';




export default function UserHomeLayout(
    { children, } : { children : React.ReactNode}
    ){

    return (
       <> 
       <div className={'w-full'}>
            {/* Sign In Header */}
            <nav className={'py-6  shadow-md items-center'}>
            <div className={'container mx-auto flex justify-between gap-3'}>
                <div className={'rounded-full p-1 bg-slate-100 hover:bg-slate-200'}>
                    <Link href="/"><IconArrowLeft /> </Link>     
                </div>            
                <h4 className={'font-semibold'}>Retail passports</h4>
                <Link href="/" className='text-xl font-bold tracking-wide font-sans subpixel-antialiased hover:font-extrabold'> <span className={'text-2xl'}>&#129434;</span> Fitzyo</Link>
            </div>
            </nav>            

        </div>
        <div className={'container mx-auto my-20'}>
        
        {children}
        </div>
        
        </>
    )
}

