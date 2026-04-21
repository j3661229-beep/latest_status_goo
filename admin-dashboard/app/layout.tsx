import type { Metadata } from 'next';
import { Nunito } from 'next/font/google';
import './globals.css';
import { Providers } from './providers';

const nunito = Nunito({
  subsets: ['latin'],
  variable: '--font-nunito',
  weight: ['400', '500', '600', '700', '800', '900'],
});

export const metadata: Metadata = {
  title: 'Status Go Admin — Main Dashboard',
  description: 'Admin panel for Status Go — manage templates, creators, users, and analytics',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={nunito.variable}>
      <body className="bg-surface font-sans antialiased">
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
