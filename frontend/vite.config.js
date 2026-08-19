import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: '../backend-dorm/dist',
    emptyOutDir: true,
  },
  server: {
    host: '127.0.0.1', // บังคับรันบน IPv4
    allowedHosts: true, // แก้ปัญหา "Invalid Host header" โดยอนุญาตทุก Host
    open: true, // เปิดเบราว์เซอร์อัตโนมัติเมื่อเซิร์ฟเวอร์รัน
    proxy: {
      '/api': {
        target: 'http://localhost:4282', // ชี้ไปที่ Backend Go (Dormitory)
        changeOrigin: false
      },
      '/uploads': {
        target: 'http://localhost:4282',
        changeOrigin: false
      }
    }
  },
  optimizeDeps: {
    force: true, // บังคับให้ Vite รีบิลด์แคช
    include: ['recharts', 'lodash'] // แก้บัค require_isUnsafeProperty
  }
})