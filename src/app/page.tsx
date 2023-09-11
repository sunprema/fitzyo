/* eslint-disable @next/next/no-img-element */
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
          <Image src="./images/web_shopping.svg"  alt="Fitzyo signup" width={500} height={300} className="object-cover"/>
          
          <SignInOutButton />
          </div>
      </section>
     
      {/* Retail passport */}
  <div className="box-border pl-10 pr-10 max-[767px]:pl-5 max-[767px]:pr-5" >
	<div className="ml-auto mr-auto w-full max-w-7xl">
		<div className="pb-32 pt-32 max-[991px]:pb-24 max-[991px]:pt-24 max-[767px]:pb-16 max-[767px]:pt-16">
			<div className="grid-rows-[auto] grid-cols-[1fr_1fr] grid auto-cols-[1fr] items-center gap-20 max-[991px]:grid-cols-[1fr] max-[991px]:grid-rows-[auto_auto] max-[991px]:justify-items-start max-[991px]:gap-20 max-[479px]:gap-8">
				<div  className="max-[991px]:max-w-[45rem]">
					<h2 className="mb-4 mt-6 text-[2rem] font-bold leading-[1.1] dark:text-white max-[767px]:text-[2.5rem]">Retail Passport</h2>
					<div className="p-4 pl-0 pr-0 pt-0 max-[991px]:pl-0 max-[991px]:pr-0 max-[991px]:pt-0 max-[767px]:pl-0 max-[767px]:pr-0 max-[767px]:pt-0 max-[479px]:pl-0 max-[479px]:pr-0 max-[479px]:pt-0">
					</div>
					<div className="max-w-[30rem]">
						<p className="mb-0 text-[#aeaeae]">Retail Passport is an online card that will hold your measurements securely. You need to
            schedule a visit to one of our authorized partners location and a professional will take
            the measurement. You can get it for everyone in the family. You can attach retail
            passports to your profile.</p>
            <p className={'mt-4 font-light'}>
            Our partners will have a use Fitzyo button in their website, If you click and login using that, Fitzyo will send your measurements to partners site.
            They will then use it to display items that will fit you.
          </p>
					</div>
					<div className="p-12 pl-0 pr-0 pt-0 max-[991px]:p-10 max-[991px]:pl-0 max-[991px]:pr-0 max-[991px]:pt-0 max-[767px]:p-6 max-[767px]:pl-0 max-[767px]:pr-0 max-[767px]:pt-0 max-[479px]:pl-0 max-[479px]:pr-0 max-[479px]:pt-0">
					</div>
					<a href="#" className="inline-block cursor-pointer rounded-sm border border-solid border-orange-500 bg-orange-500 px-6 py-4 text-center font-bold text-black [transition:border_0.2s_ease_0s,_background-color_0.2s_ease_0s] hover:border hover:border-solid hover:border-black hover:bg-white">Get started</a>
				</div>
				<div id="w-node-_32ac721e-e9c7-df62-93b1-53979800fc73-fb808401"  className="[grid-area:span_1_/_span_1_/_span_1_/_span_1]">
        <Image src="./images/retail_card.svg"  alt="Fitzyo signup" width={500} height={300} className="object-cover"/>
				</div>
			</div>
		</div>
	</div>
</div>
      
      </main>
  );
}
