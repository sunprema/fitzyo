import { cookies } from 'next/headers';
import Link from 'next/link';
import { createServerComponentClient } from '@supabase/auth-helpers-nextjs';
import { ChevronDown, Import, User, User2 } from 'lucide-react';

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
import BackButton from '@/app/components/backButton';

const RetailPassports = async () => {
  const supabase = createServerComponentClient<Database>({
    cookies,
  });
  const {
    data: { session },
  } = await supabase.auth.getSession();

  let retailPassports = null ;

  if( session?.user ){
    const { data: USER_RETAIL_PASSPORTS, error }= await supabase
    .from('USER_RETAIL_PASSPORTS')
    .select("*")

    if(error == null){
      console.log(JSON.stringify(USER_RETAIL_PASSPORTS, null, 2))
      retailPassports = USER_RETAIL_PASSPORTS
    }else{
      console.log(error)
    }
    
  }
  
  console.log(JSON.stringify(session, null, 2));

  return (
    <div className={'w-full'}>
      {/* Sign In Header */}
      <nav className={'items-center  py-6 shadow-md'}>
        <div className={'container mx-auto flex justify-between gap-3'}>
          <BackButton />

          <h4 className={'font-semibold'}> Retail Passports</h4>
          <Link
            href="/"
            className="font-sans text-xl font-bold tracking-wide subpixel-antialiased hover:font-extrabold"
          >
            
            <span className={'text-2xl'}>&#129434;</span> Fitzyo
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
          <div  className={'mt-16 flex flex-wrap gap-8'}>
                
            {retailPassports?.map( 
              (retailPassport) =>
              
              <RetailPassportCard 
                key={retailPassport.id}
                userRetailPassport={retailPassport} />
            )
            }
                
            </div>
              
          
          
        </div>
      </div>
    </div>
  );
};
export const dynamic = 'force-dynamic';
export default RetailPassports;
