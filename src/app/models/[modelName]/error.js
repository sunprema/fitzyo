'use client'

import {useEffect} from 'react'

const errorHandler = ({error, reset}) => {
    useEffect( () => {
        console.error(error)
    },[error])

    return (
    <div>
      <h2>Something went wrong!</h2>
      <button
        className={'bg-green-300'}
        onClick={
          // Attempt to recover by trying to re-render the segment
          () => reset()
        }
      >
        Try again
      </button>
    </div>

    )
}

export default errorHandler ;