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


const ImportForm = () => {

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
        const res = await fetch('/api/')
    }



    return <h1>Import form</h1>
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