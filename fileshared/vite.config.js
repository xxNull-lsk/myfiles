import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

// https://vite.dev/config/
export default defineConfig({
  base: "./",
  plugins: [vue()],
  build: {
    chunkSizeWarningLimit: 1000, // 将警告阈值调整为 1000 kB
  }
})
