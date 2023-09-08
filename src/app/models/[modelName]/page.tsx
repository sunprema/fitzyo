'use client';

import React, { useRef, useState } from 'react';
import Link from 'next/link';
import { IconCircleArrowRightFilled } from '@tabler/icons-react';
import axios from 'axios';
import useSWR, { SWRConfig } from 'swr';

import { StylerSuggestion } from '../../../../schemas/stylerSchema';
import BackButton from '@/components/backButton';

const AI_STYLERS: { [key: string]: string } = {
  zebra: '🦓',
  peacock: '🦚',
  lion: '🦁',
  leopard: '🐆',
};

interface SuggestionRequest {
  modelName: string;
  searchText: string;
}

const fetcher = async (suggestionRequestData: SuggestionRequest) => {
  console.log(suggestionRequestData);
  const response = await axios.post('/api/models/suggestions', suggestionRequestData, {
    timeout: 15000,
  });
  return response.data;
};

const useSearchSuggestionHook = (suggestionRequest: SuggestionRequest) => {
  console.log(' useSearchSuggestionHook used here!');
  const { data, error, isLoading } = useSWR<StylerSuggestion, Error>(suggestionRequest, fetcher);
  return {
    data,
    error,
    isLoading,
  };
};

const SearchSuggestionUI = ({ suggestionRequest }: { suggestionRequest: SuggestionRequest }) => {
  const { data, error, isLoading } = useSearchSuggestionHook(suggestionRequest);
  let returnElement = <h1>Loading...</h1>;
  if (isLoading) returnElement = <h1>Loading...</h1>;
  if (error) returnElement = <h1> {` Error : ${error}`}</h1>;
  if (data)
    returnElement = (
      <p>
        <pre>{JSON.stringify(data, null, 2)}</pre>
      </p>
    );

  return returnElement;
};

const placeholderTexts: { [key: string]: string } = {
  zebra: 'Help me pack for a business event in Japan in february',
  peacock: 'planning to attend a Indian wedding, suggest me what should I wear',
  leopard: 'Going for a scuba diving in Andaman, help me pack',
  lion: 'I am planning for a Hawaii trip in October, suggest me what I need to pack.',
};

const AIStylerUI = ({ modelName }: { modelName: string }) => {
  const [searchText, setSearchText] = useState(placeholderTexts[modelName]); //TODO: remove the hardcoded searchText
  const [suggestionRequest, setSuggestionRequest] = useState<SuggestionRequest>({
    modelName: '',
    searchText: '',
  });
  const inputRef = useRef(null);

  const handleSearchText = () => {
    alert(searchText);
    setSuggestionRequest({ modelName, searchText });
  };

  return (
    //First display the header, It should also have the styler name & emoji
    <div className={'w-full'}>
      {/*Header */}
      <nav className={'items-center  py-6 shadow-md'}>
        <div className={'container mx-auto flex justify-between gap-3'}>
          <BackButton />

          <h4 className={'font-semibold'}> AI Styler </h4>
          <Link
            href="/"
            className="font-sans text-xl font-bold tracking-wide subpixel-antialiased hover:font-extrabold"
          >
            {' '}
            <span className={'text-2xl'}>&#129434;</span> Fitzyo
          </Link>
        </div>
      </nav>

      {/* Display the emoji and the character */}
      <div className={'container mx-auto mt-12 rounded-md bg-white p-12 shadow-md'}>
        {/* Emoji and the description */}
        <div className={'flex items-center justify-evenly align-top'}>
          <div className={'text-center text-9xl '}>{AI_STYLERS[modelName]}</div>
          <div className={'text-left'}>
            <h2 className={'font-bold'}>{modelName}</h2>
            <h6 className={'font-semibold'}> Trendy desciption of {modelName}</h6>
          </div>
        </div>

        {/* search box */}
        <div className={'flex flex-col'}>
          <label className={'py-8 font-extrabold'}>
            Lets shop!
            <span className={'ml-4 font-normal'}> What are we shopping?!</span>
          </label>

          <div
            className={`flex rounded-lg border-solid  border-gray-800 bg-slate-300 p-2 py-4 pl-10`}
          >
            <input
              type="text"
              ref={inputRef}
              value={searchText}
              onChange={(e) => setSearchText(e.target.value)}
              placeholder={placeholderTexts[modelName]}
              className={
                'w-full  bg-slate-300 focus:border-blue-500 focus:text-gray-900 focus:outline-none '
              }
            />

            <IconCircleArrowRightFilled
              size={'48'}
              stroke="green"
              color="green"
              className={
                'shrink-0 rounded-full py-2 hover:cursor-pointer hover:bg-green-500 focus:bg-green-500'
              }
              onClick={handleSearchText}
            />
          </div>
        </div>

        <div>
          <SWRConfig
            value={{
              revalidateIfStale: false,
              revalidateOnMount: false,
              revalidateOnFocus: false,
              revalidateOnReconnect: false,
              shouldRetryOnError: false,
            }}
          >
            <SearchSuggestionUI suggestionRequest={suggestionRequest} />
          </SWRConfig>
        </div>
      </div>
    </div>
  );
};

const AIModel = ({ params }: { params: { modelName: string } }) => {
  if (params.modelName in AI_STYLERS) {
    return <AIStylerUI modelName={params.modelName} />;
  } else {
    throw new Error(`Model name ${params.modelName} is not valid`);
  }
};

export default AIModel;
