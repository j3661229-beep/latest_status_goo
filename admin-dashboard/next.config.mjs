/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'assets.statusgo.app' },
      { protocol: 'https', hostname: 'lh3.googleusercontent.com' },
      { protocol: 'https', hostname: 'placehold.co' },
    ],
  },
  env: {
    API_BASE_URL: process.env.API_BASE_URL || 'http://localhost:3000/api/v1',
  },
};

export default nextConfig;
