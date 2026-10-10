import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { readFileSync } from 'node:fs'

const pkg = JSON.parse(readFileSync(new URL('./package.json', import.meta.url), 'utf-8'))

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), tailwindcss()],
  // Versiya nazorati uchun: package.json versiyasi bundlega joylanadi.
  define: { __APP_VERSION__: JSON.stringify(pkg.version) },
  server: {
    // subdomen portallari: lvh.me, admin.lvh.me, firma.lvh.me -> 127.0.0.1
    // nip.io/sslip.io -> so'ralgan IP (masalan firma.100.69.182.71.nip.io ->
    // 100.69.182.71), shu orqali boshqa qurilmalardan ham subdomen-portal
    // aniqlash ishlaydi. qrbite.uz — haqiqiy domen, VPS'dagi nginx Tailscale
    // orqali shu Mac'ga reverse-proxy qiladi (qarang deploy/nginx/qrbite.uz.conf).
    host: true,
    allowedHosts: ['.lvh.me', '.nip.io', '.sslip.io', '.vidamarket.uz', '.qrbite.uz'],
  },
})
