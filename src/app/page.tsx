
import SignInOutButton from '@/app/components/signInOut';
import Link from 'next/link';



const StylersSection =() => {
  return(
    
  <div className={'grid grid-cols-1 sm:grid-cols-4 gap-4 p-6 justify-items-center' }>
    
    {/* First card - Zebra */}
    <div className={'flex flex-col justify-center shadow-lg max-w-sm hover:shadow-2xl hover:cursor-pointer transition-all hover:scale-105'}>
    <Link href="/models/zebra">  
      <div className={'bg-red-100  text-center text-9xl p-4'}>      
          &#129427;
      </div> 

      <div className={'bg-red-100 pb-4 pl-4 font-semibold'}>      
          Zebra
      </div> 
      <div className={'bg-white pb-12'}>      
          <p className='p-6 font-mono text-sm text-slate-800'>I&apos;m trained in Formals!</p>
          <p className='px-6 font-mono text-xs text-slate-800'>If you are looking for formal wears, shoes, belts and suits, talk to me!</p>
      </div> 
     </Link>
    </div>

    {/* Second card - Peacock */}
    <div className={'flex flex-col justify-center shadow-lg max-w-sm hover:shadow-2xl hover:cursor-pointer transition-all hover:scale-105'}>
    <Link href="/models/peacock">   
      <div className={'bg-yellow-100  text-center text-9xl p-4'}>      
        &#129434;
      </div> 

      <div className={'bg-yellow-100 pb-4 pl-4 font-semibold'}>      
          Peacock
      </div> 
      <div className={'bg-white pb-12'}>      
          <p className='p-6 font-mono text-sm text-slate-800'>I&apos;m trained in Ethnic wears!</p>
          <p className='px-6 font-mono text-xs text-slate-800'>If you are looking to buy Ethnic wears and accessories, talk to me!</p>
      </div> 
    </Link> 
    </div>

    {/* Third card - Leopard */}
    <div className={'flex flex-col justify-center shadow-lg max-w-sm hover:shadow-2xl hover:cursor-pointer transition-all hover:scale-105'}>
    <Link href="/models/leopard">  
      <div className={'bg-blue-100  text-center text-9xl p-4'}>      
      &#128006;
      </div> 

      <div className={'bg-blue-100 pb-4 pl-4 font-semibold'}>      
          Leopard
      </div> 
      <div className={'bg-white pb-12'}>      
          <p className='p-6 font-mono text-sm text-slate-800'>I&lsquo;m trained in Sports wears!.</p>
          <p className='px-6 font-mono text-xs text-slate-800'>If you are looking to buy athletic wears, shoes, jackets, talk to me!</p>
      </div>
    </Link>
    </div>

    {/* Fourth card - Lion */}
    <div className={'flex flex-col justify-center shadow-lg max-w-sm hover:shadow-2xl hover:cursor-pointer transition-all hover:scale-105'}>
    <Link href="/models/lion">  
      <div className={'bg-green-50 text-center text-9xl p-4'}>      
      🦁
      </div> 

      <div className={'bg-green-50 pb-4 pl-4 font-semibold'}>      
          Lion
      </div> 
      <div className={'bg-white pb-12'}>      
          <p className='p-6 font-mono text-sm text-slate-800'>I&apos;m the king!</p>
          <p className='px-6 font-mono text-xs text-slate-800'>Come to me for all other items. I work with all the Stylers. talk to me!</p>
      </div>
    </Link>
    </div>

    
    </div>
  )

}






export default function Home() {
  return (
      <div>
  <header className='relative top-0 left-0 right-0 z-10 shadow-md'>
          <nav className=" py-6 flex justify-between align-middle items-center container mx-auto" >
            <Link href="/" 
                  className='text-xl font-bold tracking-wide font-sans subpixel-antialiased hover:font-extrabold'>
               <span className={'text-2xl'}>&#129434;&nbsp;</span> 
               Fitzyo
            </Link>

            <Link className=' hover:text-green-400' 
                href="/aboutUs" > 
                Business Partners
            </Link>

            <Link className=' hover:text-green-400' 
                href="/aboutUs" > 
                Services
            </Link>

            <Link className=' hover:text-green-400' 
                href="/aboutUs" > 
                About us
            </Link>

            <SignInOutButton />

            
          </nav>          
</header>
<section className='my-12 mx-auto px-6 py-20 text-center text-neutral-800'>

      <h2 className="scroll-m-20 pb-2 text-3xl font-semibold tracking-tight transition-colors first:mt-0">
        Measure once, buy anywhere.
      </h2>
      <h3 className={'mb-4 font-medium'}>Fitzyo is your fashion assistant, <span className={'bg-yellow-200'}> perfected!</span>.</h3>            
      <p className={'my-8 text-center mx-auto w-8/12 font-medium text-green-600'}>
      <span className={'mb-4'}>Fitzyo helps in finding stuff that just fits you, using your Retail passport issued at our partners location.</span>
      </p>
      <p className={'mb-4 text-center mx-auto w-8/12 font-medium text-green-600'}>              
      <span>Sign up!,</span>
      <span className='font-semibold'> Get your Retail Passport,</span>
      <span> Shop with our AI Stylers.</span>
      </p>
          
  </section>

  {/* Retail passport */}  
  <section className='my-6 container mx-auto bg-green-100'>
          <div className={'px-6 py-20 r text-neutral-800'}>
            <h1 className={'mb-6 text-2xl font-bold'}>What is Retail Passport?</h1>
            <h3 className={'mb-4 font-medium'}> 
            Retail Passport is an online card that will hold your measurements securely. 
            You need to schedule a visit to one of our authorized partners location and a professional will take the measurement.
            You can get it for everyone in the family. You can attach retail passports to your profile.
            </h3>

            <p className={'mt-4 font-medium'}>
            When you want to shop in Fitzyo, you will select a Retail passport, magically, everything you browse in our site will fit your size.
            This can be used at our partners websites too after you authorize them to use the passport for the logged in session.
            </p>

            <p className={'mt-4 font-medium'}>
            See the <Link className={' bg-yellow-100'} href={"/aboutUs"}> About us</Link> for why this is important.
            </p>
          </div>
  </section>

  {/* Stylers  */}  
  <section className='mt-12 container mx-auto bg-neutral-50'>
          <div className={'px-6 py-20 r text-neutral-800'}>
            <h1 className={'mb-6 text-2xl font-bold text-center'}>Meet our AI Stylers.</h1>
            
            <h3 className={'mb-3 text-lg font-medium text-slate-800'}> Hi There!</h3>
            <h3 className={'mb-2 font-medium text-base text-slate-600'}>We are AI models trained with fashion data from our retail partners. You can train us too by ❤️ items.</h3>          
            <h3 className={'font-medium text-base text-slate-600'}>With your Retail Passport, We can assist you in finding right stuff that &ldquo;fitz you&rdquo; ...Fitzyo!  </h3>            
                        
          </div>

          <StylersSection />
  </section>


      </div>
  );
}
