import Link from 'next/link';
import BackButton from '@/components/backButton';
import { Gem } from 'lucide-react';

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <div className={"w-full"}>
        {/*Header */}
        <nav className="items-center  py-6 shadow-md">
          <div className="container mx-auto flex justify-between gap-3">
            <BackButton />
            <h4 className="font-semibold"> Retail Passport</h4>
          <Link href="/">
          <div className="flex gap-2"><Gem className="h-6 w-6" /> 
            <h4 className="font-sans text-xl font-bold tracking-wide subpixel-antialiased hover:font-extrabold">Fitzyo</h4>
          </div>
          </Link>
          </div>
        </nav>
        {children}
      </div>
  );
}
