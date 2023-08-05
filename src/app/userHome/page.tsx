import Image from 'next/image';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';

interface CardData {
  name: string;
  issued_at: string;
  issue_date: string;
  expiry_date: string;
  passport_number: string;
  logo?: string;
}

const cardsData = [
  {
    name: 'Sundar',
    issued_at: 'Mens warehouse',
    issue_date: '01/02/2023',
    expiry_date: '01/02/2025',
    passport_number: 'A12345',
    logo: 'Nautica-logo.svg',
  },

  {
    name: 'Shiner',
    issued_at: 'JC Penny',
    issue_date: '02/02/2023',
    expiry_date: '02/02/2025',
    passport_number: 'A20000',
    logo: 'mens-wearhouse-logo-vector-1.svg',
  },

  {
    name: 'Shiner',
    issued_at: 'JC Penny',
    issue_date: '02/02/2023',
    expiry_date: '02/02/2025',
    passport_number: 'A20000',
    logo: 'Nautica-logo.svg',
  },
  {
    name: 'Shiner',
    issued_at: 'JC Penny',
    issue_date: '02/02/2023',
    expiry_date: '02/02/2025',
    passport_number: 'A20000',
    logo: 'mens-wearhouse-logo-vector-1.svg',
  },
  {
    name: 'Shiner',
    issued_at: 'JC Penny',
    issue_date: '02/02/2023',
    expiry_date: '02/02/2025',
    passport_number: 'A20000',
    logo: 'mens-wearhouse-logo-vector-1.svg',
  },
];

export default function UserHome() {
  return (
    <div className={'flex flex-col flex-wrap gap-10 space-y-10 md:flex-row md:space-y-0'}>
      {cardsData.map((retailPassport: CardData) => {
        return (
          <Card
            key={retailPassport.passport_number}
            className="bg-muted transition-all duration-200 hover:scale-110"
          >
            <CardHeader>
              <Image
                src={`/images/${retailPassport.logo}`}
                alt={`Retail passport for ${retailPassport.name}`}
                width={300}
                height={150}
                className="rounded-md object-cover"
              />
            </CardHeader>
            <CardContent>
              <CardTitle>{retailPassport.name}</CardTitle>
              <CardDescription>{retailPassport.issued_at}</CardDescription>
            </CardContent>
          </Card>
        );
      })}
    </div>
  );
}
