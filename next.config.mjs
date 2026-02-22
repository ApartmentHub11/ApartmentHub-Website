/** @type {import('next').NextConfig} */
const nextConfig = {
    // Enable CSS Modules with .module.css pattern (default in Next.js)
    // Images from external domains if needed
    images: {
        domains: [],
    },
    eslint: {
        // Temporary: unblock `next build` while ESLint 9 + legacy config is stabilized
        ignoreDuringBuilds: true,
    },

    webpack(config) {
        // Allow importing videos/other binary assets from src/ (Vite-style)
        config.module.rules.push({
            test: /\.(mp4|webm|ogg|mp3|wav|flac|aac|pdf)$/i,
            type: 'asset/resource',
        });

        return config;
    },
    // Redirect non-www to www and strip BOM characters
    async redirects() {
        return [
            // Strip %EF%BB%BF (Zero Width No-Break Space / BOM) from the end of URLs
            // Crawlers sometimes append this invisible character causing 404s
            {
                source: '/:path*%EF%BB%BF',
                destination: '/:path*',
                permanent: true,
            },
            {
                source: '/:path*%E2%80%8B', // Also strip standard zero-width space if present
                destination: '/:path*',
                permanent: true,
            }
        ];
    },
    // Headers for robots.txt, sitemap.xml etc.
    async headers() {
        return [
            {
                source: '/robots.txt',
                headers: [
                    { key: 'Content-Type', value: 'text/plain' },
                ],
            },
            {
                source: '/sitemap.xml',
                headers: [
                    { key: 'Content-Type', value: 'application/xml' },
                ],
            },
        ];
    },
};

export default nextConfig;
