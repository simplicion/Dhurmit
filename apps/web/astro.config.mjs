import { defineConfig } from 'astro/config';

// https://astro.build/config
export default defineConfig({
  site: 'https://dhurmit.app',
  trailingSlash: 'never',
  build: {
    format: 'directory'
  }
});
