import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Future Flux - RWA DEX Platform',
  description: 'Decentralized exchange for Real World Assets',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  )
}
