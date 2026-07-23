import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  server: {
    // subdomen portallari: lvh.me, admin.lvh.me, firma.lvh.me -> 127.0.0.1
    host: true,
    allowedHosts: ['.lvh.me'],
  },
})
