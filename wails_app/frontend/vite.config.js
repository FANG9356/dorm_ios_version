import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
// import basicSsl from '@vitejs/plugin-basic-ssl'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
  server: {
    host: true, // เปิดให้เชื่อมต่อจากอุปกรณ์อื่นในวง LAN ได้
    allowedHosts: true, // แก้ปัญหา "Invalid Host header" โดยอนุญาตทุก Host
    open: false, // ปิดการเปิดเบราว์เซอร์อัตโนมัติ (Wails จะเปิดหน้าต่างเอง)
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