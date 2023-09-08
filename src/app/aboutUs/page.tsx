'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import BackButton from '../../components/backButton';
import { Gem } from 'lucide-react';

const AboutUs = () => {
  const [seconds, setSeconds] = useState(0);

  useEffect(() => {
    const interval = setInterval(() => setSeconds((s) => s + 1), 1000);

    return () => clearInterval(interval);
  }, []);

  return (
    <>
      <div className={"w-full"}>
        {/*Header */}
        <nav className="items-center  py-6 shadow-md">
          <div className="container mx-auto flex justify-between gap-3">
            <BackButton />
            <h4 className="font-semibold"> About us</h4>
          <Link href="/">
          <div className="flex gap-2"><Gem className="h-6 w-6" /> 
            <h4 className="font-sans text-xl font-bold tracking-wide subpixel-antialiased hover:font-extrabold">Fitzyo</h4>
          </div>
          </Link>
          </div>
        </nav>
      </div>

      <div className={"container mx-auto"}>
        <div className="mt-20 py-6">
          <h1 className="border-b-2 border-orange-500 pb-4 text-2xl font-bold">Mission</h1>
          <blockquote
            className={
              'pt-12 px-12 pb-6 text-xl font-light italic'
            }
          >
            Fitzyo&apos;s mission is to ensure the perfect fit for every customer, every time,
            eliminating the need for returns. By integrating retail partners and your
            personalized measurements, we aim to provide seamless, tailored shopping experiences,
            transforming the way you find your perfect fashion match.
          </blockquote>
        </div>

        <div>
        <h1 className="border-b-2 border-orange-500 pb-4 text-2xl font-semibold">Big Picture</h1>
        

        <div>
          <blockquote
            cite="https://www.liveabout.com/the-high-cost-of-retail-returns-2890350"
            className={
              'p-12 text-xl font-semibold italic dark:text-white'
            }
          >
            <svg
              className="mb-4 h-8 w-8"
              aria-hidden="true"
              xmlns="http://www.w3.org/2000/svg"
              fill="currentColor"
              viewBox="0 0 18 14"
            >
              <path d="M6 0H2a2 2 0 0 0-2 2v4a2 2 0 0 0 2 2h4v1a3 3 0 0 1-3 3H2a1 1 0 0 0 0 2h1a5.006 5.006 0 0 0 5-5V2a2 2 0 0 0-2-2Zm10 0h-4a2 2 0 0 0-2 2v4a2 2 0 0 0 2 2h4v1a3 3 0 0 1-3 3h-1a1 1 0 0 0 0 2h1a5.006 5.006 0 0 0 5-5V2a2 2 0 0 0-2-2Z" />
            </svg>
            <i className='font-light tracking-wide'>
              In a report focused on the losses due to returns, IHL Group estimated that worldwide,
              <span className="bg-yellow-200 p-1 dark:font-extrabold dark:text-black">retailers lose more than $600 billion each year</span> to sales returns. Labeled the
              &quot;ghost economy&quot; by IHL, retailers in North America accounted for $183
              billion of that number alone. Why the high rate of return? Well, according to the
              study,<span className="bg-yellow-200 p-1 dark:font-extrabold dark:text-black">wrong size was the number one reason.</span>
            </i>
            <a
              className={'mx-2 rounded-sm  p-2 text-sm'}
              href="https://www.liveabout.com/the-high-cost-of-retail-returns-2890350"
              target="_blank"
            >
              Go to article
            </a>
          </blockquote>

          <blockquote
            cite="https://www.theatlantic.com/magazine/archive/2021/11/free-returns-online-shopping/620169/"
            className="pt-12 px-12 pb-12 text-xl font-semibold italic text-gray-900 dark:text-white"            
          >
            <svg
              className="mb-4 h-8 w-8"
              aria-hidden="true"
              xmlns="http://www.w3.org/2000/svg"
              fill="currentColor"
              viewBox="0 0 18 14"
            >
              <path d="M6 0H2a2 2 0 0 0-2 2v4a2 2 0 0 0 2 2h4v1a3 3 0 0 1-3 3H2a1 1 0 0 0 0 2h1a5.006 5.006 0 0 0 5-5V2a2 2 0 0 0-2-2Zm10 0h-4a2 2 0 0 0-2 2v4a2 2 0 0 0 2 2h4v1a3 3 0 0 1-3 3h-1a1 1 0 0 0 0 2h1a5.006 5.006 0 0 0 5-5V2a2 2 0 0 0-2-2Z" />
            </svg>
              
            <i className='font-light tracking-wide'>
              Even some of the biggest retailers in the world now see rampant returns as an
              existential threat.
            </i>
            <a
              className={'mx-2 rounded-sm p-2 text-sm'}
              href="https://www.theatlantic.com/magazine/archive/2021/11/free-returns-online-shopping/620169/"
              target="_blank"
            >
              Go to article
            </a>
          </blockquote>

            
            <h1 className="text-lg font-medium italic px-12 pb-12">
              While you are reading this,
              <span
                className={
                  'mx-2 inline-block w-40 bg-red-500 p-2 text-center  text-3xl font-extrabold text-white'
                }
              >
                {seconds}
              </span>
              truck loads of returned clothing is sent to Landfill or Burnt.
            </h1>
            
          
          </div>
          <div>
          <h1 className="border-b-2 border-orange-500 pb-4 text-2xl font-semibold">Fitzyo wants to fix this.</h1>
            
            <h1 className={'mb-2 px-12 py-6 text-lg font-medium'}>
              Much of the challenges are due to the prevailing shopping experience , where customers
              are left to deal with sizing ambiguities.
            </h1>
            <h1 className={'mb-2 px-12 text-lg font-medium'}>
              With Fitzyo&apos;s &quot;Retail Passport&quot; and the &quot;AI Stylers&quot;, users
              can say goodbye to the guesswork and frequent returns while saving Environment and
              Retailers!.
            </h1>
          </div>
        </div>
      </div>
    </>
  );
};

export default AboutUs;
