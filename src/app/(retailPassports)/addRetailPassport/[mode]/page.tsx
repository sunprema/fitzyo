'use client'

import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import * as z from 'zod';
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
import { Button } from '@/components/ui/button';
import { useState } from 'react';
import { sleep } from '@/app/api/utils/utilFunctions';


const ImportForm = () => {

    const [importing, setImporting] = useState<boolean>(false);

    const ImportSchema = z.object({
       passportId : z
        .string({required_error : 'Please enter the Retail Passport reference id'})
        .min(5, {message: 'Minimum length is 5 characters'})
        .max(15, {message: 'Maximum length is 15 characters'}) 
    })

    const importForm = useForm<z.infer<typeof ImportSchema>>({
        resolver: zodResolver(ImportSchema)
    })

    async function onSubmit( data:z.infer<typeof ImportSchema>){
        setImporting(true);
        console.log( JSON.stringify(data, null, 2))
        await sleep(3000)
        setImporting(false);
    }

    return (
        <div className={'flex flex-col items-center'}>
            <section className={'my-8 flex w-full flex-col items-center'}>
                <h1 className={'text-3xl font-extrabold leading-tight tracking-tighter md:text-4xl'}>
                    Import Retail Passport
                </h1>
                <Form {...importForm}>
                    <form onSubmit={importForm.handleSubmit(onSubmit)}>
                        <FormField 
                            control={importForm.control}
                            name="passportId"
                            render={({ field}) => (
                                <FormItem>
                                    <div className={"mt-4 flex flex-col gap-2"}>
                                        <FormLabel className={'min-w-fit'}>Retail Passport Id</FormLabel>
                                        <FormControl>
                                            <Input placeholder='Retail passport Id' {...field}></Input>
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

        </div>
    )
}

const MenForm = () => {
    return <h1>Men form</h1>
}

const WomenForm = () => {
    return <h1>Women Form</h1>
}




export default function Page({ params }: { params: { mode: string } }) {
    
    switch( params.mode){

        case "men":
            return <MenForm />

        case "women":
            return <WomenForm />

        case "import":
            return <ImportForm />         

        default :
            return <h1> Mode {params.mode} not valid</h1>   
    }


    
}