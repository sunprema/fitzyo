import Link from 'next/link';
import BackButton from '../../components/backButton';

export default function UserHomeLayout({ children }: { children: React.ReactNode }) {
  return (
    <>
      <div className={'w-full'}>
        {/* Sign In Header */}
        <nav className={'items-center  py-6 shadow-md'}>
          <div className={'container mx-auto flex justify-between gap-3'}>
            <BackButton />
            <h4 className={'font-semibold'}>Retail passports</h4>
            <Link
              href="/"
              className="font-sans text-xl font-bold tracking-wide subpixel-antialiased hover:font-extrabold"
            >
              {' '}
              <span className={'text-2xl'}>&#129434;</span> Fitzyo
            </Link>
          </div>
        </nav>
      </div>
      <div className={'container mx-auto my-20'}>{children}</div>
    </>
  );
}
