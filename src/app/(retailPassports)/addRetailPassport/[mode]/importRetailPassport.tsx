'use client'

import { useState } from 'react';
import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import * as z from 'zod';

import { Button } from '@/components/ui/button';
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from '@/components/ui/form';
import { Input } from '@/components/ui/input';
import { sleep } from '@/app/api/utils/utilFunctions';
import { useToast } from "@/components/ui/use-toast"

const ImportForm = () => {
    const [importing, setImporting] = useState<boolean>(false);
    const {toast} = useToast()
  
    const ImportSchema = z.object({
      passportId: z
        .string({ required_error: 'Please enter the Retail Passport reference id' })
        .min(5, { message: 'Minimum length is 5 characters' })
        .max(15, { message: 'Maximum length is 15 characters' }),
    });
  
    const importForm = useForm<z.infer<typeof ImportSchema>>({
      resolver: zodResolver(ImportSchema),
    });
  
    async function onSubmit(data: z.infer<typeof ImportSchema>) {
      toast({
          title: "Imported data for Retail Passport",
          description: "Friday, February 10, 2023 at 5:57 PM",
              
      })
      setImporting(true);
      console.log(JSON.stringify(data, null, 2));
      await sleep(3000);
      
      setImporting(false);
      
    }
  
    return (
      <div className={'flex flex-col items-center'}>
        <section className={'my-8 flex w-full flex-col items-center'}>
          <h1 className={'text-xl font-semibold leading-tight tracking-tighter md:text-2xl'}>
            Import Retail Passport
          </h1>
          <Form {...importForm}>
            <form onSubmit={importForm.handleSubmit(onSubmit)}>
              <FormField
                control={importForm.control}
                name="passportId"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Retail Passport Id</FormLabel>
                      <FormControl>
                        <Input placeholder="Retail passport Id" {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription>
                      Enter the Retail passport Id you received at our partners location.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
  
              <div className={'flex items-center justify-center'}>
                <Button type="submit" className={'mt-4'} disabled={importing}>
                  {importing ? 'Importing...' : 'Import'}
                </Button>
              </div>
            </form>
          </Form>
        </section>
        <Button onClick={ () => {
          alert("Hello")
          toast({
          title: "Imported data for Retail Passport, You can add a nick name and save ",
          description: "Friday, February 10, 2023 at 5:57 PM",
          variant : 'destructive'       
      })}}>Click me</Button>
      </div>
    );
  };


  export default ImportForm;