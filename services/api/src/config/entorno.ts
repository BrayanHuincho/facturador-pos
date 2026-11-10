import { config as cargarDotenv } from 'dotenv';
import { z } from 'zod';

cargarDotenv({ quiet: true });

const textoOpcional = z
  .string()
  .optional()
  .transform((valor) => (valor && valor.trim() ? valor.trim() : undefined));

const esquema = z
  .object({
    NODE_ENV: z.string().default('development'),
    LOG_LEVEL: z.string().default('info'),
    TRUST_PROXY: z
      .string()
      .optional()
      .transform((valor) => valor === 'true'),
    PORT: z.coerce.number().int().positive().default(4200),
    DATABASE_URL: z.string().min(1),
    SUPABASE_URL: z.url().transform((url) => url.replace(/\/+$/, '')),
    SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
    SUPABASE_JWKS_URL: textoOpcional,
    SUPABASE_JWT_SECRET: textoOpcional,
    CLAVE_CIFRADO: z.string().regex(/^[0-9a-fA-F]{64}$/, 'CLAVE_CIFRADO debe tener 64 caracteres hexadecimales'),
    SUNAT_GATEWAY_URL: z.url().transform((url) => url.replace(/\/+$/, '')),
    SUNAT_GATEWAY_TOKEN: z.string().min(1),
    SUNAT_DEMO_USUARIO: z.string().min(1),
    SUNAT_DEMO_CLAVE: z.string().min(1),
    CONSULTA_DOCUMENTO_URL: textoOpcional,
    CONSULTA_DOCUMENTO_TOKEN: textoOpcional,
    CORS_ORIGENES: z.string().default(''),
  })
  .transform((valores) => ({
    ...valores,
    SUPABASE_JWKS_URL: valores.SUPABASE_JWKS_URL ?? `${valores.SUPABASE_URL}/auth/v1/.well-known/jwks.json`,
  }));

const resultado = esquema.safeParse(process.env);

if (!resultado.success) {
  const variables = resultado.error.issues.map((problema) => problema.path.join('.')).join(', ');
  throw new Error(`Variables de entorno inválidas: ${variables}`);
}

export const entorno = resultado.data;
export type Entorno = typeof entorno;
