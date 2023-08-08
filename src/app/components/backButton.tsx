'use client'


import { IconArrowLeft } from '@tabler/icons-react';
import { useRouter } from 'next/navigation';


export default function BackButton(){
    const router = useRouter()
    return (
        <div className={'rounded-full bg-background p-1 hover:bg-slate-200'} 
            onClick={() => router.back()}>
        <IconArrowLeft />
            
        </div>    
    )
}
