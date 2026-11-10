import { entorno } from './config/entorno.js';
import { pool } from './db/pool.js';
import { crearApp } from './http/app.js';
import { rutas } from './http/rutas.js';

const app = await crearApp(rutas);

async function cerrar(senal: NodeJS.Signals) {
  app.log.info({ senal }, 'Cerrando servidor');
  await app.close();
  await pool.end();
  process.exit(0);
}

process.once('SIGTERM', cerrar);
process.once('SIGINT', cerrar);

await app.listen({ port: entorno.PORT, host: '0.0.0.0' });
