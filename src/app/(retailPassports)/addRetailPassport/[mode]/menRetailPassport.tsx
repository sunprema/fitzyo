'use client'

import { useState } from 'react';
import { zodResolver } from '@hookform/resolvers/zod';
import { useForm } from 'react-hook-form';
import * as z from 'zod';
import { Slider } from "@/components/ui/slider"
import axios from 'axios';

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

import {
  Tabs,
  TabsContent,
  TabsList,
  TabsTrigger,
} from "@/components/ui/tabs"
import { useRouter } from 'next/navigation';


const MenForm = () => {
    const [saving, setSaving] = useState<boolean>(false);
    const {toast} = useToast()
    const router = useRouter()
  
    const MenFormSchema = z.object({

      nick_name:z
      .string({required_error :'Nick name is required'})
      .min(3,{message: 'Minimum of three characters'})
      .max(30, {message: 'Max of 30 characters'}),
      
      
      shirt_neck:z
      .coerce
      .number({required_error: 'Neck size is required'})
      .gt(11,{message: 'Should be greater than 11'})
      .lt(20,{message: 'Should be less than 20'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'})
      .default(15),

      shirt_chest:z
      .coerce
      .number({required_error: 'Chest size is required'})
      .gt(30,{message: 'Should be greater than 30'})
      .lt(60,{message: 'Should be less than 60'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      shirt_waist:z
      .coerce
      .number({required_error: 'Waist size is required'})
      .gt(28,{message: 'Should be greater than 28'})
      .lt(55,{message: 'Should be less than 55'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      shirt_sleeve_length:z
      .coerce
      .number({required_error: 'Sleeve legth is required'})
      .gt(30,{message: 'Should be greater than 30'})
      .lt(40,{message: 'Should be less than 40'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      shirt_length:z
      .coerce
      .number({required_error: 'Shirt legth is required'})
      .gt(27,{message: 'Should be greater than 27'})
      .lt(32,{message: 'Should be less than 32'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      pant_waist:z
      .coerce
      .number({required_error: 'Waist size for pant is required'})
      .gt(28,{message: 'Should be greater than 28'})
      .lt(40,{message: 'Should be less than 40'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      pant_hips:z
      .coerce
      .number({required_error: 'Hip size for pant is required'})
      .gt(36,{message: 'Should be greater than 36'})
      .lt(48,{message: 'Should be less than 48'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      pant_inseam:z
      .coerce
      .number({required_error: 'Inseam for pant is required'})
      .gt(30,{message: 'Should be greater than 30'})
      .lt(34,{message: 'Should be less than 34'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      pant_outseam:z
      .coerce
      .number({required_error: 'Outseam for pant is required'})
      .gt(32,{message: 'Should be greater than 32'})
      .lt(36,{message: 'Should be less than 36'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      belt_waist_size:z
      .coerce
      .number({required_error: 'Belt waist size is required'})
      .gt(28,{message: 'Should be greater than 28'})
      .lt(40,{message: 'Should be less than 40'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      belt_length:z
      .coerce
      .number({required_error: 'Belt length is required'})
      .gt(30,{message: 'Should be greater than 30'})
      .lt(42,{message: 'Should be less than 42'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      shoe_foot_length:z
      .coerce
      .number({required_error: 'Foot length for shoe is required'})
      .gt(8.5,{message: 'Should be greater than 8.5'})
      .lt(12,{message: 'Should be less than 12'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      shoe_foot_width:z
      .coerce
      .number({required_error: 'Foot width for shoe is required'})
      .gt(3,{message: 'Should be greater than 3'})
      .lt(6,{message: 'Should be less than 6'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      shoe_arch_length:z
      .coerce
      .number({required_error: 'Foot arch length for shoe is required'})
      .gt(8,{message: 'Should be greater than 8'})
      .lt(11,{message: 'Should be less than 11'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      glove_hand_circumference:z
      .coerce
      .number({required_error: 'Glove hand circumference is required'})
      .gt(7,{message: 'Should be greater than 7'})
      .lt(10,{message: 'Should be less than 10'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

      glove_hand_length:z
      .coerce
      .number({required_error: 'Foot arch length for shoe is required'})
      .gt(6.5,{message: 'Should be greater than 8'})
      .lt(8.5,{message: 'Should be less than 11'})
      .multipleOf(0.5, {message: 'Should be in the multiples of 1/2 inch'})
      .positive({message : 'Number should be positive'}),

    });
  
    const menForm = useForm<z.infer<typeof MenFormSchema>>({
      resolver: zodResolver(MenFormSchema),
      defaultValues:{
        nick_name: 'John Doe',
        shirt_neck: 15,
        shirt_chest: 40,
        shirt_waist: 36,
        shirt_sleeve_length:35,
        shirt_length: 30,
        pant_waist: 34,
        pant_hips: 40,
        pant_inseam: 32,
        pant_outseam:34,
        belt_waist_size: 34,
        belt_length:36,
        shoe_foot_length:10,
        shoe_foot_width:5,
        shoe_arch_length:10,
        glove_hand_circumference:8,
        glove_hand_length:7

      }
    });
  
    async function onSubmit(data: z.infer<typeof MenFormSchema>) {
      setSaving(true);
      try{
        const response = await axios.post("/api/addRetailPassport", data)

        toast({
          title: "Retail passport added",
          description: "Retail passport added successfully",
        })
        router.push("/showRetailPassports")

      }catch(error){
        toast({
          title: "Retail passport failed",
          description: `Error : ${error}`,
          variant:"destructive",
      })

      }
      setSaving(false);
      
      
    }
  
    return (
      <div className={'flex flex-col items-center'}>
        <section className={'my-8 flex w-full flex-col items-center'}>
          <h1 className={'text-xl font-semibold leading-tight tracking-tighter md:text-2xl'}>
            Add new Retail passport for Men.
          </h1>
          <div className="max-w-[800px]">
          <Form {...menForm}>
            <form onSubmit={menForm.handleSubmit(onSubmit)}>


            <FormField
                control={menForm.control}
                name="nick_name"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-16 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Nick name for this Retail passport</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                     should be between 3 and 30 characters.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

            <Tabs defaultValue="shirt" className="mt-16 w-full">
              <TabsList className="grid w-full grid-cols-5">
                <TabsTrigger value="shirt">Shirt</TabsTrigger>
                <TabsTrigger value="pant">Pants</TabsTrigger>
                <TabsTrigger value="belt">Belts</TabsTrigger>
                <TabsTrigger value="shoe">Shoe</TabsTrigger>
                <TabsTrigger value="gloves">Gloves</TabsTrigger>                
              </TabsList>
              
              <TabsContent value="shirt">      
              <div className={'m-16 grid grid-cols-1 gap-8 p-8 md:grid-cols-3'}>
            

              <FormField
                control={menForm.control}
                name="shirt_neck"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Neck size</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                     should be between 12 to 20 inches.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={menForm.control}
                name="shirt_chest"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Chest size</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                     Measure around your chest, just under armpit.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={menForm.control}
                name="shirt_waist"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Waist size for shirt</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                    Measure around waist at the smallest circumference..
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={menForm.control}
                name="shirt_sleeve_length"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Sleeve length</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                    With elbow bent, measure from the center (back) of neck to elbow and down to wrist.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={menForm.control}
                name="shirt_length"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Shirt length</FormLabel>
                      <FormControl>
                        <Input {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                    should be between 27 to 32 inches.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              </div>
              </TabsContent>

               <TabsContent value="pant">      
              <div className={'m-16 grid grid-cols-1 gap-8 p-8 md:grid-cols-3'}>    
              <FormField
                control={menForm.control}
                name="pant_waist"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Waist size for pant</FormLabel>
                      <FormControl>
                        <Input {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                     should be between 28 to 40 inches.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={menForm.control}
                name="pant_hips"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Hip size for pant</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                     Stand, feet together, and measure around the largest circumference at hips.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={menForm.control}
                name="pant_inseam"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Inseam for pant</FormLabel>
                      <FormControl>
                        <Input   {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                    should be between 30 to 34 inches.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={menForm.control}
                name="pant_outseam"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Outseam for pant</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                    should be between 32 to 36 inches.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              </div>
              </TabsContent>

              <TabsContent value="belt">      
              <div className={'m-16 grid grid-cols-1 gap-8 p-8 md:grid-cols-3'}>
              <FormField
                control={menForm.control}
                name="belt_waist_size"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Waist size for belts</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                    should be between 28 to 40 inches.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={menForm.control}
                name="belt_length"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Belt length</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                    should be between 30 to 42 inches.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              </div>
              </TabsContent>

              <TabsContent value="shoe">      
              <div className={'m-16 grid grid-cols-1 gap-8 p-8 md:grid-cols-3'}>

              <FormField
                control={menForm.control}
                name="shoe_foot_length"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Foot length for shoe</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                    should be between 8.5 to 12 inches.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={menForm.control}
                name="shoe_foot_width"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Foot width for shoe</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                     should be between 3 to 6 inches.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              <FormField
                control={menForm.control}
                name="shoe_arch_length"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Foot arch length for shoe</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                    should be between 8 to 11 inches.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              </div>
              </TabsContent>

              <TabsContent value="gloves">      
              <div className={'m-16 grid grid-cols-1 gap-8 p-8 md:grid-cols-3'}>

              <FormField
                control={menForm.control}
                name="glove_hand_circumference"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Glove hand circumference</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic">
                    should be between 7 to 10 inches.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />

              <FormField
                control={menForm.control}
                name="glove_hand_length"
                render={({ field }) => (
                  <FormItem>
                    <div className={'mt-4 flex flex-col gap-2'}>
                      <FormLabel className={'min-w-fit'}>Glove hand length</FormLabel>
                      <FormControl>
                        <Input  {...field}></Input>
                      </FormControl>
                    </div>
                    <FormDescription className="text-xs italic"> 
                    should be between 6.5 to 8.5 inches.
                    </FormDescription>
                    <FormMessage />
                  </FormItem>
                )}
              />
              </div>
              </TabsContent>

              </Tabs>
              
              <div className={'flex items-center justify-center'}>
                <Button type="submit" className={'mt-4'} disabled={saving}>
                  {saving ? 'Saving...' : 'Save'}
                </Button>
              </div>
            </form>
          </Form>
          </div>
        </section>
        
      </div>
    );
  };


  export default MenForm;