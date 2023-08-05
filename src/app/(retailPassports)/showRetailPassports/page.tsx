import { cookies } from 'next/headers';
import Link from 'next/link';
import { createServerComponentClient } from '@supabase/auth-helpers-nextjs';
import { IconArrowLeft } from '@tabler/icons-react';
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

const RetailPassports = async () => {
  const supabase = createServerComponentClient<Database>({
    cookies,
  });
  const {
    data: { session },
  } = await supabase.auth.getSession();

  console.log(JSON.stringify(session, null, 2));

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
      </div>
    </div>
  );
};
export const dynamic = 'force-dynamic';
export default RetailPassports;
