import { cookies } from 'next/headers';
import Link from 'next/link';
import { createServerComponentClient } from '@supabase/auth-helpers-nextjs';
import { ChevronDown, Gem, Import, User, User2 } from 'lucide-react';
import Image from 'next/image';

import { Database } from '@/types/supabase';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import RetailPassportCard from './retailPassport';
import BackButton from '@/components/backButton';
import { redirect } from 'next/navigation';
import { RedirectType } from 'next/dist/client/components/redirect';

const Page = async () => {
  const supabase = createServerComponentClient<Database>({
    cookies,
  });
  const {
    data: { session },
  } = await supabase.auth.getSession();

  let retailPassports = null ;

  if(session == null ){
    redirect("/signIn", RedirectType.push);
  }

  if( session?.user ){
    const { data: USER_RETAIL_PASSPORTS, error }= await supabase
    .from('USER_RETAIL_PASSPORTS')
    .select("*")

    if(error == null){
      retailPassports = USER_RETAIL_PASSPORTS
    }else{
      console.log(error)
    }
  }


  
  console.log(JSON.stringify(session, null, 2));

  return (
    <div className={'w-full'}>
      {/* Sign In Header */}
      <nav className={'items-center  py-6 '}>
        <div className={'container mx-auto flex justify-between gap-3'}>
          <BackButton />

          <h4 className={'font-semibold'}> Retail Passports</h4>
          <Link href="/">
          <div className="flex gap-2"><Gem className="h-6 w-6" /> 
            <h4 className="font-sans text-xl font-bold tracking-wide subpixel-antialiased hover:font-extrabold">Fitzyo</h4>
          </div>
          </Link>
        </div>
      </nav>
      <div className="container mx-auto my-20">
        <div className="flex  flex-row-reverse ">
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button>
                Add Retail Passport <ChevronDown className="ml-2" />
              </Button>
            </DropdownMenuTrigger>

            <DropdownMenuContent className={'w-72'}>
              <DropdownMenuLabel>Retail Passport</DropdownMenuLabel>

              <DropdownMenuSeparator />
              <DropdownMenuGroup>
                <Link href={'/addRetailPassport/import'}>
                  <DropdownMenuItem>
                    <Import className="mr-2 h-4 w-4" />
                    <span>Import using retail passport id</span>
                  </DropdownMenuItem>
                </Link>
                <Link href={'/addRetailPassport/men'}>
                  <DropdownMenuItem>
                    <User2 className="mr-2 h-4 w-4" />
                    <span>Men</span>
                  </DropdownMenuItem>
                </Link>

                <Link href={'/addRetailPassport/women'}>
                  <DropdownMenuItem>
                    <User className="mr-2 h-4 w-4" />
                    <span>Women</span>
                  </DropdownMenuItem>
                </Link>
              </DropdownMenuGroup>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
        <div>
          {retailPassports?.length  && retailPassports.length > 0 
          ?
          <div  className={'mt-16 flex flex-wrap gap-8'}>
          {retailPassports?.map( 
              (retailPassport) =>
              
              <RetailPassportCard 
                key={retailPassport.id}
                userRetailPassport={retailPassport} />
            )
          }
          </div>
          :
          <div className="container mx-auto mt-20 w-[800px]">
          <h4 className="px-12 pb-12 text-lg font-medium">No Retail passports. Add one by using the button above.</h4>  
          <Image src="./images/welcome_cats.svg"
           alt="Add Retail passport" 
           width={600} height={400} />
          </div> 
          }

          
        </div>
      </div>
    </div>
  );
};
export const dynamic = 'force-dynamic';
export default Page;
