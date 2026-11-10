import type { FastifyInstance, FastifyRequest } from 'fastify';
import { z } from 'zod';
import { requerirRol } from '../../http/auth.js';
import { ErrorApi } from '../../http/errores.js';
import { cambiarEntorno, eliminarCertificado, guardarCredenciales, obtenerEstado, probarConexion, subirCertificado } from './servicio.js';

const esquemaCredenciales = z.object({
  usuario_sol: z.string().trim().min(1).max(30),
  clave_sol: z.string().min(1).max(100).optional(),
  gre_client_id: z.string().trim().min(1).max(200).optional(),
  gre_client_secret: z.string().min(1).max(500).optional(),
  envio_boletas: z.enum(['individual', 'resumen_diario']),
});

const esquemaEntorno = z.object({
  entorno: z.enum(['beta', 'produccion']),
  confirmar_ruc: z.string().trim().optional(),
});

async function leerMultipartCertificado(request: FastifyRequest): Promise<{ archivo: Buffer; clave: string }> {
  let archivo: Buffer | undefined;
  let clave = '';
  for await (const parte of request.parts()) {
    if (parte.type === 'file') {
      const contenido = await parte.toBuffer();
      if (parte.fieldname === 'archivo') archivo = contenido;
    } else if (parte.fieldname === 'clave' && typeof parte.value === 'string') {
      clave = parte.value;
    }
  }
  if (!archivo) throw new ErrorApi(400, 'ARCHIVO_REQUERIDO', 'Adjunta el certificado en el campo archivo.');
  return { archivo, clave };
}

export async function sunatConfigRutas(app: FastifyInstance) {
  const soloAdmin = { preHandler: requerirRol('admin') };
  const operacionLimitada = { ...soloAdmin, config: { rateLimit: { max: 10, timeWindow: '1 minute' } } };

  app.get('/sunat/configuracion', soloAdmin, async () => obtenerEstado());

  app.put('/sunat/credenciales', operacionLimitada, async (request) => guardarCredenciales(esquemaCredenciales.parse(request.body), request.usuario.id));

  app.post('/sunat/certificado', operacionLimitada, async (request) => {
    const { archivo, clave } = await leerMultipartCertificado(request);
    return subirCertificado(archivo, clave, request.usuario.id);
  });

  app.delete('/sunat/certificado', operacionLimitada, async (request) => eliminarCertificado(request.usuario.id));

  app.put('/sunat/entorno', operacionLimitada, async (request) => {
    const { entorno, confirmar_ruc } = esquemaEntorno.parse(request.body);
    return cambiarEntorno(entorno, confirmar_ruc, request.usuario.id);
  });

  app.post('/sunat/probar', operacionLimitada, async () => probarConexion());
}
