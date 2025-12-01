import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Configuración de desarrollo: proxya llamadas a /ventas al backend local
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/ventas': {
        target: 'http://localhost:4000',
        changeOrigin: true,
        secure: false
      }
    }
  }
})
