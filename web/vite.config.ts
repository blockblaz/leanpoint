import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: '../web-dist',
    emptyOutDir: true,
  },
  server: {
    proxy: {
      '/status': 'http://localhost:5555',
      '/metrics': 'http://localhost:5555',
      '/healthz': 'http://localhost:5555',
      '/api': 'http://localhost:5555',
    }
  }
})
