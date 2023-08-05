import Link from 'next/link';
import { IconArrowLeft } from '@tabler/icons-react';
import { Toaster } from '@/components/ui/toaster';

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <div className={'w-full'}>
      {/* Sign In Header */}
      <nav className={'items-center  py-6 shadow-md'}>
        <div className={'container mx-auto flex justify-between gap-3'}>
          <div className={'rounded-full bg-slate-100 p-1 hover:bg-slate-200'}>
            <Link href="/">
              <IconArrowLeft />{' '}
            </Link>
          </div>

          <h4 className={'font-semibold'}> Retail Passports</h4>
          <Link
            href="/"
            className="font-sans text-xl font-bold tracking-wide subpixel-antialiased hover:font-extrabold"
          >
            {' '}
            <span className={'text-2xl'}>&#129434;</span> Fitzyo
          </Link>
        </div>
      </nav>

      <div className="flex flex-1 flex-col">
        <div className="container mx-auto flex flex-1 justify-center overflow-y-auto px-4">{children}</div>
      <Toaster />
      </div>

      

      
    </div>
  );
}
