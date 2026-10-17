import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// El backend Spring Boot actual no configura CORS. Para desarrollar sin
// tocar el backend se usa un proxy del servidor de Vite: el navegador llama
// a /api en el mismo origen (5173) y Vite lo reenvia a Spring Boot (8080).
// En produccion, VITE_API_BASE_URL debe apuntar al backend real.
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: process.env.VITE_PROXY_TARGET ?? "http://localhost:8080",
        changeOrigin: true,
      },
    },
  },
});
