import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { resolve } from "node:path";

const page = (path: string) => resolve(import.meta.dirname, path);

export default defineConfig({
  plugins: [react(), tailwindcss()],
  build: {
    rollupOptions: {
      input: {
        index: page("index.html"),
        b: page("b/index.html"),
        docs: page("docs/index.html"),
      },
    },
  },
});
