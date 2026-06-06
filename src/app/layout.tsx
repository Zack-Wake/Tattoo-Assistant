import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'Tattoo Studio Assistant',
  description: 'AI assistant for tattoo artists',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className="bg-zinc-950">
      <body className={`${inter.className} text-zinc-100 antialiased`}>{children}</body>
    </html>
  )
}
