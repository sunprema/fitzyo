import Link from 'next/link';
import Image from 'next/image';
import SignInOutButton from '@/components/signInOut';

export default function Home() {
  return (
    <main>

      <section className="container m-16 mx-auto">    
          <h2 className="scroll-m-20 pb-2 text-3xl font-semibold tracking-tight  first:mt-0">
          Measure once, buy anywhere.
          </h2>
          <h4 className="text-md scroll-m-20 pb-2 font-light tracking-tight  first:mt-0">
          Fitzyo helps in finding stuff that just fits you, using your Retail passport issued at our partners location.
          </h4>
          <div className="flex gap-4 p-16 justify-evenly items-center">
          <Image src="./images/web_shopping.svg"  alt="Fitzyo signup" width={400} height={300} />
          <SignInOutButton />
          </div>
      </section>
     
      {/* Retail passport */}
      <section className="container mx-auto my-6 ">
        <div >
          <h1 className={'mb-6 text-2xl font-light'}>What is a Retail Passport?</h1>
          <h3 className={'mb-4 font-light'}>
            Retail Passport is an online card that will hold your measurements securely. You need to
            schedule a visit to one of our authorized partners location and a professional will take
            the measurement. You can get it for everyone in the family. You can attach retail
            passports to your profile.
          </h3>
          
          <p className={'mt-4 font-light'}>
            Our partners will have a use Fitzyo button in their website, If you click and login using that, Fitzyo will send your measurements to partners site.
            They will then use it to display items that will fit you.
          </p>

          <p className={'mt-4 font-medium'}>
            

            <Link href={'/aboutUs'}>
            See <span className="m-1 bg-yellow-200 dark:text-black"> About us </span>for why this is important.
            </Link>
            
          </p>
        </div>
      </section>
    </main>
  );
}
