/** @type {import('next').NextConfig} */
const nextConfig = {
  agentRules: false,
  output: process.env.ELECTRON_BUILD ? "standalone" : undefined,
  images: {
    remotePatterns: [{ protocol: "https", hostname: "**" }],
    unoptimized: !!process.env.ELECTRON_BUILD,
  },
};

module.exports = nextConfig;
