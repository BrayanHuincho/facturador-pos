import pg from 'pg';
import type { PoolClient } from 'pg';
import { entorno } from '../config/entorno.js';

export const pool = new pg.Pool({ connectionString: entorno.DATABASE_URL, max: 10 });

pool.on('error', (error) => {
  console.error(`Error en conexión inactiva del pool: ${error.message}`);
});

export async function withTransaction<T>(fn: (c: PoolClient) => Promise<T>): Promise<T> {
  const cliente = await pool.connect();
  let errorDeLiberacion: Error | undefined;
  try {
    await cliente.query('BEGIN');
    const resultado = await fn(cliente);
    await cliente.query('COMMIT');
    return resultado;
  } catch (error) {
    try {
      await cliente.query('ROLLBACK');
    } catch (errorRollback) {
      errorDeLiberacion = errorRollback instanceof Error ? errorRollback : new Error('Fallo en ROLLBACK');
    }
    throw error;
  } finally {
    cliente.release(errorDeLiberacion);
  }
}
