import path from 'path'
import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { VitePWA } from 'vite-plugin-pwa'

// https://vitejs.dev/config/
export default defineConfig({
  base: '/pasajero/',
  plugins: [
    vue(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['icons/icon.svg', 'icons/apple-touch-icon.png'],
      manifest: {
        name: 'BucaraBus — Pasajero',
        short_name: 'BucaraBus',
        description: 'Sigue tu bus en tiempo real en Bucaramanga',
        theme_color: '#667eea',
        background_color: '#667eea',
        display: 'standalone',
        orientation: 'portrait',
        scope: '/pasajero/',
        start_url: '/pasajero/',
        icons: [
          { src: 'icons/icon-192x192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icons/icon-512x512.png', sizes: '512x512', type: 'image/png' },
          { src: 'icons/icon-512x512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
          { src: 'icons/icon.svg',         sizes: 'any',     type: 'image/svg+xml' }
        ]
      },
      workbox: {
        // Precache: código, estilos, íconos
        globPatterns: ['**/*.{js,css,html,svg,png,ico,woff2}'],
        navigateFallback: 'index.html',
        runtimeCaching: [
          {
            // Tiles del mapa — CacheFirst, 30 días
            // El pasajero puede ver el mapa sin internet en zonas que ya visitó
            urlPattern: /^(https:\/\/[a-z]\.basemaps\.cartocdn\.com\/.*|\/tiles\/.*)/i,
            handler: 'CacheFirst',
            options: {
              cacheName: 'map-tiles',
              expiration: { maxEntries: 500, maxAgeSeconds: 60 * 60 * 24 * 30 },
              cacheableResponse: { statuses: [0, 200] }
            }
          },
          {
            // Rutas de transporte — StaleWhileRevalidate, 7 días
            // Muestra datos cacheados al instante; actualiza en segundo plano si hay red
            urlPattern: ({ url }) => url.pathname.includes('/api/routes'),
            handler: 'StaleWhileRevalidate',
            options: {
              cacheName: 'routes-cache',
              expiration: { maxEntries: 30, maxAgeSeconds: 60 * 60 * 24 * 7 },
              cacheableResponse: { statuses: [200] }
            }
          },
          {
            // Paradas — StaleWhileRevalidate, 7 días
            urlPattern: ({ url }) => url.pathname.includes('/api/stops'),
            handler: 'StaleWhileRevalidate',
            options: {
              cacheName: 'stops-cache',
              expiration: { maxEntries: 50, maxAgeSeconds: 60 * 60 * 24 * 7 },
              cacheableResponse: { statuses: [200] }
            }
          },
          {
            // Geocodificación — NetworkFirst, 1 día (requiere internet para precisión)
            urlPattern: ({ url }) => url.pathname.includes('/api/geocoding'),
            handler: 'NetworkFirst',
            options: {
              cacheName: 'geocoding-cache',
              networkTimeoutSeconds: 5,
              expiration: { maxEntries: 100, maxAgeSeconds: 60 * 60 * 24 },
              cacheableResponse: { statuses: [200] }
            }
          }
          // NOTA: /api/shifts (buses en tiempo real) NO se cachea — siempre requiere red
        ]
      },
      devOptions: {
        enabled: true,
        type: 'module'
      }
    })
  ],
  resolve: {
    alias: {
      '@':      path.resolve(__dirname, './src'),
      '@shared': path.resolve(__dirname, '../../shared')
    }
  },
  server: {
    port: 3004,
    host: '0.0.0.0',
    proxy: {
      '/api': {
        target: 'http://localhost:3001',
        changeOrigin: true
      },
      '/socket.io': {
        target: 'http://localhost:3001',
        ws: true,
        changeOrigin: true
      },
      '/tiles': {
        target: 'http://localhost:8085',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/tiles/, '')
      }
    }
  },
  build: {
    outDir: '../../dist_pasajero',
    emptyOutDir: true,
    assetsDir: 'assets'
  }
})
