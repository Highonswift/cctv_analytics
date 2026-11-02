import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  const backendUrl = env.BACKEND_URL || "http://localhost:8010";
  const devPort = Number(env.FRONTEND_DEV_PORT) || 5174;

  return {
    plugins: [react()],
    server: {
      host: "0.0.0.0",
      port: devPort,
      proxy: {
        "/api": {
          target: backendUrl,
          changeOrigin: true,
        },
        "/media": {
          target: backendUrl,
          changeOrigin: true,
        },
      },
    },
  };
});
