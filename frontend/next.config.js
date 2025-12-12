/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  experimental: {
    serverComponentsExternalPackages: ['next-i18next', '@clerk/nextjs'],
  },
}

module.exports = nextConfig