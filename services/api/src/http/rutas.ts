import type { FastifyInstance } from 'fastify';
import { cajaRutas } from '../modulos/caja/rutas.js';
import { comprobantesRutas } from '../modulos/comprobantes/rutas.js';
import { consultasRutas } from '../modulos/consultas/rutas.js';
import { empresaRutas } from '../modulos/empresa/rutas.js';
import { guiasRutas } from '../modulos/guias/rutas.js';
import { perfilRutas } from '../modulos/perfil/rutas.js';
import { reportesRutas } from '../modulos/reportes/rutas.js';
import { resumenesRutas } from '../modulos/resumenes/rutas.js';
import { seriesRutas } from '../modulos/series/rutas.js';
import { stockRutas } from '../modulos/stock/rutas.js';
import { sunatConfigRutas } from '../modulos/sunat-config/rutas.js';
import { usuariosRutas } from '../modulos/usuarios/rutas.js';

export async function rutas(app: FastifyInstance) {
  await app.register(empresaRutas);
  await app.register(seriesRutas);
  await app.register(sunatConfigRutas);
  await app.register(usuariosRutas);
  await app.register(perfilRutas);
  await app.register(consultasRutas);
  await app.register(comprobantesRutas);
  await app.register(cajaRutas);
  await app.register(stockRutas);
  await app.register(reportesRutas);
  await app.register(resumenesRutas);
  await app.register(guiasRutas);
}
