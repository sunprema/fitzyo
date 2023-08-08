import ImportForm from './importRetailPassport';
import MenForm from './menRetailPassport';

const WomenForm = () => {
  return <h1>Women Form</h1>;
};

const Page = ({ params }: { params: { mode: string } }) => {
  switch (params.mode) {
    case 'men':
      return <MenForm />

    case 'women':
      return <WomenForm />;

    case 'import':
      return <ImportForm />;

    default:
      return <h1> Mode {params.mode} not valid</h1>;
  }
};

export default Page;
