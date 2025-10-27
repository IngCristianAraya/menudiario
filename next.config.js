/** @type {import('next').NextConfig} */
const nextConfig = {
  // Salimos del modo static export para permitir páginas dinámicas y middleware
  eslint: {
    ignoreDuringBuilds: true,
  },
  images: { unoptimized: true },
};

module.exports = nextConfig;
