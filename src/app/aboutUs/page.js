'use client'

import Link from 'next/link'
import { IconArrowLeft } from '@tabler/icons-react'
import {useState, useEffect} from 'react'

const AboutUs = () => {

    const [seconds, setSeconds] = useState(0); 

    useEffect(() => {
        const interval = setInterval(() => setSeconds( s => s+1) , 1000);
    
        return () => clearInterval(interval);
      }, []);

    return (
        <>
        <div className={'w-full'}>

        {/*Header */}
        <nav className={'py-6  shadow-md items-center'}>
        
        <div className={'container mx-auto flex justify-between gap-3'}>
          <div className={'rounded-full p-1 bg-slate-100 hover:bg-slate-200'}>
          <Link href="/"><IconArrowLeft /> </Link>     
          </div>
    
          <h4 className={'font-semibold'}> About us</h4>
          <Link href="/" className='text-xl font-bold tracking-wide font-sans subpixel-antialiased hover:font-extrabold'> <span className={'text-2xl'}>&#129434;</span> Fitzyo</Link>      
        </div>
    
        </nav>
      </div>    
    
    <div className={'container mx-auto'}>

    <div className='mt-20 text-2xl font-bold bg-slate-100 py-6 px-2'>
    <h1>Mission</h1>
    <blockquote className={'text-xl italic font-semibold text-gray-900 dark:text-white from-neutral-300 p-12'} >
    Fitzyo&apos;s mission is to ensure the perfect fit for every customer, every time, eliminating the need for returns. By integrating advanced AI technology with personalized measurements, we aim to provide seamless, tailored shopping experiences, transforming the way you find your perfect fashion match.
    </blockquote>
    </div>

    <div className='mt-20 text-2xl font-bold'>
    <h1>Big Picture</h1>
    </div>
    
    <div>
    
    <blockquote cite="https://www.liveabout.com/the-high-cost-of-retail-returns-2890350" 
    className={'text-xl italic font-semibold text-gray-900 dark:text-white from-neutral-300 p-12'}>
        <svg className="w-8 h-8 text-gray-400 dark:text-gray-600 mb-4" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 18 14">
            <path d="M6 0H2a2 2 0 0 0-2 2v4a2 2 0 0 0 2 2h4v1a3 3 0 0 1-3 3H2a1 1 0 0 0 0 2h1a5.006 5.006 0 0 0 5-5V2a2 2 0 0 0-2-2Zm10 0h-4a2 2 0 0 0-2 2v4a2 2 0 0 0 2 2h4v1a3 3 0 0 1-3 3h-1a1 1 0 0 0 0 2h1a5.006 5.006 0 0 0 5-5V2a2 2 0 0 0-2-2Z"/>
        </svg>
    <i>In a report focused on the losses due to returns, IHL Group estimated that worldwide, retailers lose more than $600 billion each year to sales returns. Labeled the "ghost economy" by IHL, retailers in North America accounted for $183 billion of that number alone. 
    Why the high rate of return? Well, according to the study,<span className={'bg-yellow-200'}>wrong size was the number one reason.</span> 
    </i>
    <a className={'mx-2 p-2 bg-green-100 rounded-sm text-sm'}
    href="https://www.liveabout.com/the-high-cost-of-retail-returns-2890350"
    target="_blank">Go to article</a>
    </blockquote>

    <blockquote cite="https://www.theatlantic.com/magazine/archive/2021/11/free-returns-online-shopping/620169/" 
    className={'text-xl italic font-semibold text-gray-900 dark:text-white from-neutral-300 p-12'}>
        <svg className="w-8 h-8 text-gray-400 dark:text-gray-600 mb-4" aria-hidden="true" xmlns="http://www.w3.org/2000/svg" fill="currentColor" viewBox="0 0 18 14">
            <path d="M6 0H2a2 2 0 0 0-2 2v4a2 2 0 0 0 2 2h4v1a3 3 0 0 1-3 3H2a1 1 0 0 0 0 2h1a5.006 5.006 0 0 0 5-5V2a2 2 0 0 0-2-2Zm10 0h-4a2 2 0 0 0-2 2v4a2 2 0 0 0 2 2h4v1a3 3 0 0 1-3 3h-1a1 1 0 0 0 0 2h1a5.006 5.006 0 0 0 5-5V2a2 2 0 0 0-2-2Z"/>
        </svg>
    <i>Even some of the biggest retailers in the world now see rampant returns as an existential threat.</i>
    <a className={'mx-2 p-2 bg-green-100 rounded-sm text-sm'}
    href="https://www.theatlantic.com/magazine/archive/2021/11/free-returns-online-shopping/620169/"
    target="_blank">Go to article</a>
    </blockquote>
    
    <blockquote className={'text-xl italic font-semibold text-gray-900 dark:text-white from-neutral-300 p-12'}>  
    <h1 className={'font-semibold text-lg mx-auto'} >
      While you are reading this,
      <div className={'inline-block p-3 w-40 text-center mx-2 bg-red-600  text-white text-6xl font-extrabold'}>
      {seconds}
      </div>
      truck loads of returned clothing is sent to Landfill or Burnt.
    </h1>
      
    </blockquote>
    <div className={'bg-slate-100 shadow-2xl'}>
    <div className='text-2xl font-bold border-t border-solid border-spacing-8 py-6 px-2'>
    <h4>Fitzyo wants to fix this.</h4>
    </div>  
    <h1 className={'font-medium text-lg mx-auto mb-2 pb-1 px-2'} >
      Much of the challenges are due to the prevailing shopping experience , where customers are left to deal with sizing ambiguities.      
    </h1> 
    <h1 className={'font-semibold text-lg mx-auto mb-12 pb-12 px-2'} >
      
      With Fitzyo's "Retail Passport" and the "AI Stylers", users can say goodbye to the guesswork and frequent returns while saving Environment and Retailers!.
    </h1>
    </div>
    </div>
    </div>
    
    </>      
    )
    
}

export default AboutUs