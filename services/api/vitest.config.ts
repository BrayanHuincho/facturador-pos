import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts', 'src/**/*.spec.ts'],
    testTimeout: 30_000,
    env: {
      NODE_ENV: 'test',
      DATABASE_URL: 'postgres://prueba:prueba@127.0.0.1:5432/prueba',
      SUPABASE_URL: 'http://127.0.0.1:54321',
      SUPABASE_SERVICE_ROLE_KEY: 'clave-de-servicio-de-prueba',
      SUPABASE_JWT_SECRET: 'secreto-jwt-de-prueba-con-longitud-suficiente',
      CLAVE_CIFRADO: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      SUNAT_GATEWAY_URL: 'http://127.0.0.1:4210',
      SUNAT_GATEWAY_TOKEN: 'token-de-prueba',
      SUNAT_DEMO_USUARIO: 'usuario-demo-de-prueba',
      SUNAT_DEMO_CLAVE: 'clave-demo-de-prueba',
    },
  },
});
