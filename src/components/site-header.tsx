'use client'

import { siteConfig } from "@/config/site"

import { MainNav } from "@/components/main-nav"
import { ThemeToggle } from "@/components/theme-toggle"
import SignInOutButton from "./signInOut"

export function SiteHeader() {
  return (
    <header className="sticky top-0 z-40 w-full rounded-none border-b bg-slate-600 text-white shadow-lg dark:bg-slate-600">
      <div className="flex h-16 items-center space-x-4 px-4 sm:justify-between sm:space-x-0">
        <MainNav items={siteConfig.mainNav} />
        <div className="flex flex-row-reverse">
          <SignInOutButton />
          <ThemeToggle />
        </div>
          
      </div>
    </header>
  )
}