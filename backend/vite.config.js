import {
    defineConfig
} from 'vite';
import laravel from 'laravel-vite-plugin';
import tailwindcss from "@tailwindcss/vite";

export default defineConfig({
    plugins: [
        laravel({
            input: [
                'resources/css/app.css',
                'resources/js/app.js',
                'resources/js/passkeys.js',
            ],
            refresh: true,
        }),
        tailwindcss(),
    ],
    build: {
        // ApexCharts (~570KB) قطعةٌ تُحمَّل عند أول مخطط في الصفحة (resources/js/charts.js)، لا مع كل صفحة.
        chunkSizeWarningLimit: 600,
    },
    server: {
        cors: true,
        watch: {
            ignored: ['**/storage/framework/views/**'],
        },
    },
});
