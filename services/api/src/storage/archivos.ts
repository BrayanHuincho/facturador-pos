import { createClient } from '@supabase/supabase-js';
import { entorno } from '../config/entorno.js';

const BUCKET_DOCUMENTOS = 'documentos';
const SEGUNDOS_URL_FIRMADA = 600;

export const supabaseAdmin = createClient(entorno.SUPABASE_URL, entorno.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false, autoRefreshToken: false },
});

export async function subirDocumento(ruta: string, buffer: Buffer, tipo: string): Promise<string> {
  const { error } = await supabaseAdmin.storage.from(BUCKET_DOCUMENTOS).upload(ruta, buffer, { contentType: tipo, upsert: true });
  if (error) throw new Error(`No se pudo guardar el documento ${ruta}: ${error.message}`);
  return ruta;
}

export async function urlFirmada(ruta: string, segundos: number = SEGUNDOS_URL_FIRMADA): Promise<string> {
  const { data, error } = await supabaseAdmin.storage.from(BUCKET_DOCUMENTOS).createSignedUrl(ruta, segundos);
  if (error || !data) throw new Error(`No se pudo firmar la URL de ${ruta}: ${error?.message ?? 'sin datos'}`);
  return data.signedUrl;
}
