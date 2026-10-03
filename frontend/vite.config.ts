/// <reference types="vitest/config" />
import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"
import { VitePWA } from "vite-plugin-pwa"

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: "autoUpdate",
      includeAssets: ["favicon.svg", "icons.svg", "pwa/apple-touch-icon.png"],
      manifest: {
        name: "NEPSE Trade Journal",
        short_name: "NEPSE Journal",
        description: "Mobile-first NEPSE trade journaling and analytics workspace.",
        theme_color: "#003893",
        background_color: "#f3f5f8",
        display: "standalone",
        start_url: "/dashboard",
        icons: [
          { src: "/pwa/icon-192.png", sizes: "192x192", type: "image/png" },
          { src: "/pwa/icon-512.png", sizes: "512x512", type: "image/png" },
          { src: "/pwa/icon-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
        ],
      },
      workbox: {
        globPatterns: ["**/*.{js,css,html,svg,png,woff2}"],
        runtimeCaching: [
          {
            urlPattern: ({ url }) => url.pathname.startsWith("/api/"),
            handler: "NetworkFirst",
            options: {
              cacheName: "api-cache",
              networkTimeoutSeconds: 3,
              expiration: { maxEntries: 60, maxAgeSeconds: 60 * 60 },
            },
          },
        ],
      },
    }),
  ],
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: "./src/test/setup.ts",
    css: false,
    exclude: ["node_modules/**", "dist/**"],
  },
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:3000",
        changeOrigin: true,
      },
      // POST /login goes to Rails; opening the /login page in the browser stays with the app.
      "/login": {
        target: "http://localhost:3000",
        changeOrigin: true,
        bypass: (req) => (req.headers.accept?.includes("text/html") ? "/index.html" : undefined),
      },
      "/logout": { target: "http://localhost:3000", changeOrigin: true },
      "/cable": {
        target: "ws://localhost:3000",
        ws: true,
      },
    },
  },
  build: {
    sourcemap: false,
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes("node_modules/react") || id.includes("react-router-dom")) return "react"
          if (id.includes("recharts")) return "charts"
          if (id.includes("framer-motion")) return "motion"
          if (id.includes("axios") || id.includes("@tanstack/react-query")) return "vendor"
          return undefined
        },
      },
    },
  },
})
