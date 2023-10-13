import { ReactNode } from 'react';
import ImportForm from './importRetailPassport';
import MenForm from './menRetailPassport';

const WomenForm = () => {
  return <h1>Women Form</h1>;
};

const Page = ({ params }: { params: { mode: string } }) => {
  let form:ReactNode = null
  switch (params.mode) {
    case 'men':
      form = <MenForm />
      break
    case 'women':
      form =  <WomenForm />;
      break
    case 'import':
      form = <ImportForm />;
      break
    default:
      form = <h1> Mode {params.mode} not valid</h1>;
  }
  return (
    <div>
      <section className={'my-8 flex w-full flex-col items-center'}>
          <h1 className={'text-xl font-semibold leading-tight tracking-tighter md:text-2xl'}>
            Add new Retail passport for Men.
          </h1>
          {form}
      </section>    

    </div>

  )

};

export default Page;
