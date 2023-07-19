import { NextResponse } from "next/server";


const middleware = (request) => {
    return NextResponse.redirect(new URL('/home', request.url))
}

export { middleware } ;

export const config = {
    matcher : ''
};