import { createHash } from 'node:crypto';
import type { PoolClient } from 'pg';
import { encolar } from '../../cola/encolar.js';
import { registrarAuditoria } from '../../db/auditoria.js';
import { withTransaction } from '../../db/pool.js';
import { ErrorApi } from '../../http/errores.js';
import { generarPdfVistaPrevia } from '../../pdf/generar.js';
import type { ComprobantePdf, FormatoPdf } from '../../pdf/peticion.js';
import { ErrorDatosSunat, ErrorRedSunat } from '../../sunat/cliente.js';
import type { UsuarioAutenticado } from '../../http/auth.js';
import {
  cadenaQr,
  calcularComprobante,
  decimal,
  esSinDocumento,
  leyendasDe,
  letraDeSerie,
  liquidarPagos,
  motivoDeNota,
  notaCopiaElAfectado,
  pendienteDeCredito,
  totalesDeItemsEmitidos,
  validarCliente,
  validarCuotas,
  validarDescuentos,
  validarDetraccion,
  validarFechaEmision,
  validarFechaNota,
  validarSaldoNota,
  validarTipoCambio,
  type TipoDocumentoIdentidad,
  type TotalesComprobante,
} from '../../dominio/tributos/index.js';
import type { CuerpoNota, CuerpoVenta, ItemCuerpo } from './esquemas.js';
import {
  agruparStock,
  bloquearComprobante,
  buscarSerie,
  cargarEmpresa,
  comprobanteCompleto,
  horaEnLima,
  hoyEnLima,
  insertarFila,
  itemsDe,
  moverStock,
  reservarCorrelativo,
  turnoAbierto,
  type EmpresaContexto,
} from './repositorio.js';

interface LineaResuelta {
  producto_id: string | null;
  codigo: string | null;
  descripcion: string;
  unidad: string;
  cantidad: string;
  precio: string;
  descuento: string;
  afectacion: string;
  aplica_icbper: boolean;
  controla_stock: boolean;
}

interface ClienteSnapshot {
  cliente_id: string | null;
  tipo_documento: TipoDocumentoIdentidad;
  numero_documento: string;
  nombre: string;
  direccion: string | null;
}

interface ProductoFila {
  id: string;
  codigo: string | null;
  nombre: string;
  unidad: string;
  precio: string;
  afectacion: string;
  aplica_icbper: boolean;
  controla_stock: boolean;
}

export interface ResultadoEmision {
  comprobante: NonNullable<Awaited<ReturnType<typeof comprobanteCompleto>>>;
  repetido: boolean;
}

function canonico(valor: unknown): unknown {
  if (Array.isArray(valor)) return valor.map(canonico);
  if (valor && typeof valor === 'object') {
    return Object.fromEntries(
      Object.entries(valor as Record<string, unknown>)
        .sort(([a], [b]) => a.localeCompare(b))
        .map(([clave, contenido]) => [clave, canonico(contenido)]),
    );
  }
  return valor;
}

export const huellaDe = (operacion: string, usuarioId: string, cuerpo: unknown): string =>
  createHash('sha256').update(JSON.stringify(canonico({ operacion, usuarioId, cuerpo }))).digest('hex');

async function buscarRepetido(c: PoolClient, clave: string, huella: string): Promise<ResultadoEmision | null> {
  await c.query('SELECT pg_advisory_xact_lock(hashtextextended($1, 0))', [`idempotencia:${clave}`]);
  const existente = await c.query<{ id: string }>('SELECT id FROM comprobantes WHERE clave_idempotencia = $1', [clave]);
  const id = existente.rows[0]?.id;
  if (!id) return null;
  const auditoria = await c.query<{ huella: string | null }>(
    `SELECT detalle->>'huella' AS huella FROM auditoria WHERE entidad = 'comprobantes' AND entidad_id = $1 AND detalle ? 'huella' LIMIT 1`,
    [id],
  );
  if (auditoria.rows[0]?.huella !== huella) {
    throw new ErrorApi(409, 'IDEMPOTENCIA_CONFLICTO', 'La clave de idempotencia ya se usó con otros datos.');
  }
  return { comprobante: (await comprobanteCompleto(c, id))!, repetido: true };
}

async function resolverLineas(c: PoolClient, items: ItemCuerpo[]): Promise<LineaResuelta[]> {
  const ids = [...new Set(items.flatMap((item) => (item.producto_id ? [item.producto_id] : [])))];
  const productos = new Map<string, ProductoFila>();
  if (ids.length) {
    const { rows } = await c.query<ProductoFila>(
      'SELECT id, codigo, nombre, unidad, precio, afectacion, aplica_icbper, controla_stock FROM productos WHERE id = ANY($1::uuid[]) AND activo',
      [ids],
    );
    for (const fila of rows) productos.set(fila.id, fila);
  }
  return items.map((item, indice) => {
    const producto = item.producto_id ? productos.get(item.producto_id) : undefined;
    if (item.producto_id && !producto) throw new ErrorApi(422, 'PRODUCTO_NO_ENCONTRADO', `El producto del ítem ${indice + 1} no existe o está inactivo.`);
    const descripcion = item.descripcion ?? producto?.nombre;
    const precio = item.precio_unitario ?? producto?.precio;
    if (!descripcion || precio === undefined) throw new ErrorApi(422, 'ITEM_INCOMPLETO', `El ítem ${indice + 1} necesita descripción y precio.`);
    return {
      producto_id: producto?.id ?? null,
      codigo: item.codigo ?? producto?.codigo ?? null,
      descripcion,
      unidad: item.unidad ?? producto?.unidad ?? 'NIU',
      cantidad: item.cantidad,
      precio,
      descuento: item.descuento ?? '0',
      afectacion: item.afectacion ?? producto?.afectacion ?? '10',
      aplica_icbper: producto?.aplica_icbper ?? false,
      controla_stock: producto?.controla_stock ?? false,
    };
  });
}

const totalesDe = (lineas: LineaResuelta[], empresa: EmpresaContexto, preciosIncluyenIgv: boolean): TotalesComprobante => {
  validarDescuentos(lineas);
  return calcularComprobante(
    lineas.map((linea) => ({ cantidad: linea.cantidad, precio: linea.precio, tipo_afectacion_igv: linea.afectacion, descuento: linea.descuento, aplica_icbper: linea.aplica_icbper })),
    { precios_incluyen_igv: preciosIncluyenIgv, porcentaje_igv: empresa.igv_porcentaje },
  );
};

async function clienteDeVenta(c: PoolClient, cuerpo: CuerpoVenta): Promise<ClienteSnapshot> {
  if (cuerpo.cliente_id) {
    const { rows } = await c.query<Omit<ClienteSnapshot, 'cliente_id'> & { id: string }>('SELECT id, tipo_documento, numero_documento, nombre, direccion FROM clientes WHERE id = $1 AND activo', [cuerpo.cliente_id]);
    const fila = rows[0];
    if (!fila) throw new ErrorApi(404, 'CLIENTE_NO_ENCONTRADO', 'Cliente no encontrado.');
    return { cliente_id: fila.id, tipo_documento: fila.tipo_documento, numero_documento: fila.numero_documento, nombre: fila.nombre, direccion: fila.direccion };
  }
  const datos = cuerpo.cliente;
  if (!datos || esSinDocumento({ tipo_documento: datos.tipo_documento, numero_documento: datos.numero_documento })) {
    const nombre = datos?.nombre && datos.nombre.toUpperCase() !== 'CLIENTES VARIOS' ? datos.nombre : 'CLIENTES VARIOS';
    return { cliente_id: null, tipo_documento: '0', numero_documento: '00000000', nombre, direccion: datos?.direccion || null };
  }
  return { cliente_id: null, tipo_documento: datos.tipo_documento, numero_documento: datos.numero_documento, nombre: datos.nombre || 'CLIENTES VARIOS', direccion: datos.direccion || null };
}

async function persistirCliente(c: PoolClient, cliente: ClienteSnapshot): Promise<string | null> {
  if (cliente.cliente_id || cliente.tipo_documento === '0') return cliente.cliente_id;
  const { rows } = await c.query<{ id: string }>(
    `INSERT INTO clientes (tipo_documento, numero_documento, nombre, direccion) VALUES ($1, $2, $3, $4)
     ON CONFLICT (tipo_documento, numero_documento) DO UPDATE SET numero_documento = EXCLUDED.numero_documento
     RETURNING id`,
    [cliente.tipo_documento, cliente.numero_documento, cliente.nombre, cliente.direccion],
  );
  return rows[0]!.id;
}

function liquidarVenta(cuerpo: CuerpoVenta, lineas: LineaResuelta[], empresa: EmpresaContexto, cliente: ClienteSnapshot, fechaEmision: string) {
  const totales = totalesDe(lineas, empresa, empresa.precios_incluyen_igv);
  const gratuito = totales.total.isZero() && totales.op_gratuitas.greaterThan(0);
  if (!totales.total.greaterThan(0) && !gratuito) throw new ErrorApi(422, 'TOTAL_CERO', 'El comprobante debe tener un importe mayor a cero.');
  validarCliente(cuerpo.tipo, cliente, totales.total, cuerpo.moneda);
  validarTipoCambio(cuerpo.moneda, cuerpo.tipo_cambio);

  let neto = totales.total;
  let detraccion: Record<string, unknown> | null = null;
  if (cuerpo.detraccion) {
    const monto = validarDetraccion(cuerpo.tipo, cuerpo.moneda, totales.total, cuerpo.detraccion.porcentaje);
    neto = totales.total.sub(monto);
    detraccion = { ...cuerpo.detraccion, codigo_medio_pago: cuerpo.detraccion.codigo_medio_pago ?? '001', monto: monto.toNumber() };
  }

  const liquidacion = liquidarPagos(cuerpo.pagos, cuerpo.forma_pago === 'contado' ? totales.total : neto, cuerpo.forma_pago);
  const cuotas = cuerpo.forma_pago === 'credito' ? validarCuotas(cuerpo.cuotas, pendienteDeCredito(neto, liquidacion.recibido), fechaEmision) : null;
  const leyendas = leyendasDe(totales.total, cuerpo.moneda, { gratuito, detraccion: Boolean(detraccion) });
  return { totales, liquidacion, cuotas, detraccion, leyendas, neto };
}

const fechaDe = (solicitada: string | undefined, tipoBase: '01' | '03'): string => {
  const fecha = solicitada ?? hoyEnLima();
  validarFechaEmision(fecha, hoyEnLima(), tipoBase);
  return fecha;
};

const columnasDeTotales = (totales: TotalesComprobante) => ({
  op_gravadas: totales.op_gravadas.toFixed(2),
  op_exoneradas: totales.op_exoneradas.toFixed(2),
  op_inafectas: totales.op_inafectas.toFixed(2),
  op_gratuitas: totales.op_gratuitas.toFixed(2),
  descuento_total: totales.descuento_total.toFixed(2),
  igv: totales.igv.toFixed(2),
  icbper: totales.icbper.toFixed(2),
  total: totales.total.toFixed(2),
});

async function insertarItems(c: PoolClient, comprobanteId: string, lineas: LineaResuelta[], totales: TotalesComprobante): Promise<void> {
  for (const [orden, linea] of lineas.entries()) {
    const item = totales.items[orden]!;
    await insertarFila(c, 'comprobante_items', {
      comprobante_id: comprobanteId,
      producto_id: linea.producto_id,
      orden,
      codigo: linea.codigo,
      descripcion: linea.descripcion,
      unidad: linea.unidad,
      cantidad: item.cantidad.toFixed(4),
      precio_unitario: item.precio_unitario.toFixed(6),
      valor_unitario: item.valor_unitario.toFixed(6),
      descuento: item.descuento.toFixed(2),
      afectacion: item.tipo_afectacion_igv,
      base: item.base_igv.toFixed(2),
      igv: item.igv.toFixed(2),
      icbper: item.icbper.toFixed(2),
      total: item.total.toFixed(2),
    });
  }
}

function traducirConflictos(error: unknown): never {
  const codigo = (error as { code?: string; constraint?: string }).code;
  if (codigo === '23505' && (error as { constraint?: string }).constraint?.includes('correlativo')) {
    throw new ErrorApi(409, 'NUMERO_DUPLICADO', 'Ya existe un comprobante con ese número. Revisa el último correlativo de la serie.');
  }
  if (codigo === '23514' && (error as { constraint?: string }).constraint?.includes('stock')) {
    throw new ErrorApi(409, 'STOCK_INSUFICIENTE', 'No hay stock suficiente para esta venta.');
  }
  throw error;
}

async function prepararVenta(c: PoolClient, cuerpo: CuerpoVenta) {
  const empresa = await cargarEmpresa(c);
  const lineas = await resolverLineas(c, cuerpo.items);
  const cliente = await clienteDeVenta(c, cuerpo);
  const fecha = fechaDe(cuerpo.fecha_emision, cuerpo.tipo === '01' ? '01' : '03');
  return { empresa, lineas, cliente, fecha, ...liquidarVenta(cuerpo, lineas, empresa, cliente, fecha) };
}

export async function previsualizar(cuerpo: CuerpoVenta) {
  return withTransaction(async (c) => {
    const { lineas, cliente, fecha, totales, liquidacion, cuotas, detraccion, leyendas, neto } = await prepararVenta(c, cuerpo);
    return {
      tipo: cuerpo.tipo,
      fecha_emision: fecha,
      moneda: cuerpo.moneda,
      forma_pago: cuerpo.forma_pago,
      cliente,
      ...columnasDeTotales(totales),
      neto: neto.toFixed(2),
      recibido: liquidacion.recibido.toFixed(2),
      vuelto: liquidacion.vuelto.toFixed(2),
      cuotas,
      detraccion,
      leyendas,
      items: lineas.map((linea, orden) => {
        const item = totales.items[orden]!;
        return {
          producto_id: linea.producto_id,
          codigo: linea.codigo,
          descripcion: linea.descripcion,
          unidad: linea.unidad,
          cantidad: item.cantidad.toFixed(4),
          precio_unitario: item.precio_unitario.toFixed(6),
          valor_unitario: item.valor_unitario.toFixed(6),
          descuento: item.descuento.toFixed(2),
          afectacion: item.tipo_afectacion_igv,
          base: item.base_igv.toFixed(2),
          igv: item.igv.toFixed(2),
          icbper: item.icbper.toFixed(2),
          total: item.total.toFixed(2),
        };
      }),
    };
  });
}

export async function vistaPreviaPdf(usuario: UsuarioAutenticado, cuerpo: CuerpoVenta, formato: FormatoPdf): Promise<Buffer> {
  const borrador = await withTransaction(async (c): Promise<ComprobantePdf> => {
    const { empresa, lineas, cliente, fecha, totales, cuotas, detraccion, leyendas } = await prepararVenta(c, cuerpo);
    const serie = await buscarSerie(c, {
      tipo: cuerpo.tipo,
      serie: cuerpo.serie,
      establecimientoObligatorio: usuario.rol === 'cajero' ? usuario.establecimiento_id : null,
      establecimientoPreferido: usuario.establecimiento_id,
    });
    const local = await c.query<{ direccion: string | null }>('SELECT direccion FROM establecimientos WHERE id = $1', [serie.establecimiento_id]);
    const perfil = await c.query<{ nombre: string | null }>('SELECT nombre FROM perfiles WHERE id = $1', [usuario.id]);
    return {
      tipo: cuerpo.tipo,
      serie: serie.serie,
      correlativo: 0,
      fecha_emision: fecha,
      hora_emision: horaEnLima(),
      moneda: cuerpo.moneda,
      tipo_cambio: cuerpo.tipo_cambio ?? '1',
      forma_pago: cuerpo.forma_pago,
      cuotas,
      cliente_tipo_documento: cliente.tipo_documento,
      cliente_numero_documento: cliente.numero_documento,
      cliente_nombre: cliente.nombre,
      cliente_direccion: cliente.direccion,
      ...columnasDeTotales(totales),
      detraccion: detraccion as ComprobantePdf['detraccion'],
      leyendas,
      afectado_tipo: null,
      afectado_serie: null,
      afectado_correlativo: null,
      motivo_codigo: null,
      motivo_descripcion: null,
      estado: 'pendiente',
      hash: null,
      qr: null,
      entorno: empresa.entorno,
      establecimiento_direccion: local.rows[0]?.direccion ?? null,
      usuario_nombre: perfil.rows[0]?.nombre ?? null,
      igv_porcentaje: empresa.igv_porcentaje,
      items: lineas.map((linea, orden) => {
        const item = totales.items[orden]!;
        return {
          codigo: linea.codigo,
          descripcion: linea.descripcion,
          unidad: linea.unidad,
          cantidad: item.cantidad.toFixed(4),
          precio_unitario: item.precio_unitario.toFixed(6),
          valor_unitario: item.valor_unitario.toFixed(6),
          descuento: item.descuento.toFixed(2),
          afectacion: item.tipo_afectacion_igv,
          total: item.total.toFixed(2),
        };
      }),
    };
  });
  try {
    return await generarPdfVistaPrevia(borrador, formato);
  } catch (error) {
    if (error instanceof ErrorRedSunat || error instanceof ErrorDatosSunat) {
      throw new ErrorApi(503, 'PDF_NO_DISPONIBLE', 'No se pudo generar la vista previa. Inténtalo de nuevo.');
    }
    throw error;
  }
}

export async function emitirVenta(usuario: UsuarioAutenticado, clave: string, cuerpo: CuerpoVenta): Promise<ResultadoEmision> {
  const huella = huellaDe('venta', usuario.id, cuerpo);
  try {
    return await withTransaction(async (c) => {
      const repetido = await buscarRepetido(c, clave, huella);
      if (repetido) return repetido;

      const empresa = await cargarEmpresa(c);
      const lineas = await resolverLineas(c, cuerpo.items);
      const cliente = await clienteDeVenta(c, cuerpo);
      const fecha = fechaDe(cuerpo.fecha_emision, cuerpo.tipo === '01' ? '01' : '03');
      const { totales, liquidacion, cuotas, detraccion, leyendas } = liquidarVenta(cuerpo, lineas, empresa, cliente, fecha);

      const serie = await buscarSerie(c, {
        tipo: cuerpo.tipo,
        serie: cuerpo.serie,
        establecimientoObligatorio: usuario.rol === 'cajero' ? usuario.establecimiento_id : null,
        establecimientoPreferido: usuario.establecimiento_id,
      });
      const { rows: ajustes } = await c.query<{ modulos: { caja: boolean; nota_venta: boolean }; medios_pago: string[] }>(`select modulos, medios_pago from empresa where id = 1`);
      const { modulos, medios_pago: mediosActivos } = ajustes[0];
      if (cuerpo.tipo === 'NV' && !modulos.nota_venta) {
        throw new ErrorApi(409, 'MODULO_DESACTIVADO', 'La nota de venta está desactivada en Ajustes.');
      }
      const medioInactivo = cuerpo.pagos.find((pago) => !mediosActivos.includes(pago.medio));
      if (medioInactivo) {
        throw new ErrorApi(422, 'MEDIO_PAGO_INACTIVO', `El medio de pago ${medioInactivo.medio} está desactivado en Ajustes.`);
      }
      const turnoId = await turnoAbierto(c, usuario.id);
      if (modulos.caja && !turnoId && cuerpo.pagos.some((pago) => pago.medio === 'efectivo' && decimal(pago.monto).gt(0))) {
        throw new ErrorApi(409, 'TURNO_REQUERIDO', 'Abre un turno de caja para registrar pagos en efectivo.');
      }

      const correlativo = await reservarCorrelativo(c, serie.id);
      const clienteId = await persistirCliente(c, cliente);
      const estado = cuerpo.tipo === 'NV' ? 'no_aplica' : cuerpo.tipo === '03' && empresa.envio_boletas === 'resumen_diario' ? 'por_resumen' : 'pendiente';
      const qr =
        cuerpo.tipo === 'NV'
          ? null
          : cadenaQr({ ruc: empresa.ruc, tipo: cuerpo.tipo, serie: serie.serie, correlativo, igv: totales.igv, total: totales.total, fecha_emision: fecha, cliente_tipo_documento: cliente.tipo_documento, cliente_numero_documento: cliente.numero_documento, hash: null });

      const id = await insertarFila(c, 'comprobantes', {
        establecimiento_id: serie.establecimiento_id,
        turno_id: turnoId,
        usuario_id: usuario.id,
        tipo: cuerpo.tipo,
        serie: serie.serie,
        correlativo,
        fecha_emision: fecha,
        hora_emision: horaEnLima(),
        moneda: cuerpo.moneda,
        tipo_cambio: cuerpo.tipo_cambio ?? '1',
        forma_pago: cuerpo.forma_pago,
        cuotas: cuotas ? JSON.stringify(cuotas) : null,
        cliente_id: clienteId,
        cliente_tipo_documento: cliente.tipo_documento,
        cliente_numero_documento: cliente.numero_documento,
        cliente_nombre: cliente.nombre,
        cliente_direccion: cliente.direccion,
        ...columnasDeTotales(totales),
        recibido: liquidacion.recibido.toFixed(2),
        vuelto: liquidacion.vuelto.toFixed(2),
        detraccion: detraccion ? JSON.stringify(detraccion) : null,
        leyendas: JSON.stringify(leyendas),
        estado,
        qr,
        entorno: empresa.entorno,
        clave_idempotencia: clave,
      });

      await insertarItems(c, id, lineas, totales);
      for (const pago of liquidacion.pagos) {
        await insertarFila(c, 'pagos', { comprobante_id: id, medio: pago.medio, monto: pago.monto.toFixed(2), referencia: pago.referencia });
      }
      await moverStock(c, agruparStock(lineas.map((linea) => ({ ...linea, cantidad: decimal(linea.cantidad) }))), {
        tipo: 'venta',
        signo: -1,
        establecimientoId: serie.establecimiento_id,
        comprobanteId: id,
        usuarioId: usuario.id,
      });
      await registrarAuditoria(c, { usuarioId: usuario.id, accion: 'comprobante.emitir', entidad: 'comprobantes', entidadId: id, detalle: { huella, observacion: cuerpo.observacion ?? null } });
      if (estado === 'pendiente') await encolar(c, 'enviar_comprobante', { comprobante_id: id });

      return { comprobante: (await comprobanteCompleto(c, id))!, repetido: false };
    });
  } catch (error) {
    return traducirConflictos(error);
  }
}

export async function emitirNota(usuario: UsuarioAutenticado, clave: string | null, cuerpo: CuerpoNota): Promise<ResultadoEmision> {
  const huella = huellaDe('nota', usuario.id, cuerpo);
  try {
    return await withTransaction(async (c) => {
      if (clave) {
        const repetido = await buscarRepetido(c, clave, huella);
        if (repetido) return repetido;
      }
      const afectado = await bloquearComprobante(c, cuerpo.afectado_id);
      if (!afectado || (usuario.rol === 'cajero' && afectado.usuario_id !== usuario.id)) throw new ErrorApi(404, 'COMPROBANTE_NO_ENCONTRADO', 'Comprobante no encontrado.');
      if (afectado.tipo !== '01' && afectado.tipo !== '03') throw new ErrorApi(422, 'NOTA_SOBRE_NOTA', 'Las notas solo modifican facturas o boletas.');
      if (afectado.estado !== 'aceptado' && afectado.estado !== 'observado') throw new ErrorApi(422, 'AFECTADO_NO_ACEPTADO', 'El comprobante debe estar aceptado por SUNAT para emitirle una nota.');

      const motivo = motivoDeNota(cuerpo.tipo, cuerpo.motivo_codigo);
      const fecha = fechaDe(cuerpo.fecha_emision, afectado.tipo);
      validarFechaNota(fecha, afectado.fecha_emision);

      const empresa = await cargarEmpresa(c);
      const copia = notaCopiaElAfectado(cuerpo.tipo, cuerpo.motivo_codigo, Boolean(cuerpo.items?.length));
      let lineas: LineaResuelta[];
      let totales: TotalesComprobante;
      if (copia) {
        const originales = await itemsDe(c, afectado.id);
        lineas = originales.map((item) => ({
          producto_id: item.producto_id,
          codigo: item.codigo,
          descripcion: item.descripcion,
          unidad: item.unidad,
          cantidad: item.cantidad,
          precio: item.valor_unitario,
          descuento: item.descuento,
          afectacion: item.afectacion,
          aplica_icbper: decimal(item.icbper).gt(0),
          controla_stock: false,
        }));
        totales = totalesDeItemsEmitidos(originales, empresa.igv_porcentaje);
      } else {
        lineas = await resolverLineas(c, cuerpo.items!);
        totales = totalesDe(lineas, empresa, empresa.precios_incluyen_igv);
      }
      if (!totales.total.greaterThan(0)) throw new ErrorApi(422, 'TOTAL_CERO', 'La nota debe tener un importe mayor a cero.');
      if (cuerpo.tipo === '07') {
        const acreditado = await c.query<{ suma: string }>(
          `SELECT COALESCE(SUM(total), 0) AS suma FROM comprobantes WHERE afectado_id = $1 AND tipo = '07' AND estado NOT IN ('anulado', 'rechazado', 'error')`,
          [afectado.id],
        );
        validarSaldoNota(totales.total, afectado.total, acreditado.rows[0]!.suma);
      }

      const serie = await buscarSerie(c, {
        tipo: cuerpo.tipo,
        serie: cuerpo.serie,
        establecimientoObligatorio: usuario.rol === 'cajero' ? usuario.establecimiento_id : null,
        establecimientoPreferido: afectado.establecimiento_id,
        letra: letraDeSerie(afectado.tipo),
      });
      const correlativo = await reservarCorrelativo(c, serie.id);
      const estado = afectado.resumen_id ? 'por_resumen' : 'pendiente';
      const id = await insertarFila(c, 'comprobantes', {
        establecimiento_id: serie.establecimiento_id,
        usuario_id: usuario.id,
        tipo: cuerpo.tipo,
        serie: serie.serie,
        correlativo,
        fecha_emision: fecha,
        hora_emision: horaEnLima(),
        moneda: afectado.moneda,
        tipo_cambio: afectado.tipo_cambio,
        forma_pago: 'contado',
        cliente_id: afectado.cliente_id,
        cliente_tipo_documento: afectado.cliente_tipo_documento,
        cliente_numero_documento: afectado.cliente_numero_documento,
        cliente_nombre: afectado.cliente_nombre,
        cliente_direccion: afectado.cliente_direccion,
        ...columnasDeTotales(totales),
        leyendas: JSON.stringify(leyendasDe(totales.total, afectado.moneda)),
        afectado_id: afectado.id,
        afectado_tipo: afectado.tipo,
        afectado_serie: afectado.serie,
        afectado_correlativo: afectado.correlativo,
        motivo_codigo: motivo.codigo,
        motivo_descripcion: (cuerpo.motivo_descripcion || motivo.etiqueta).slice(0, 250),
        estado,
        qr: cadenaQr({ ruc: empresa.ruc, tipo: cuerpo.tipo, serie: serie.serie, correlativo, igv: totales.igv, total: totales.total, fecha_emision: fecha, cliente_tipo_documento: afectado.cliente_tipo_documento, cliente_numero_documento: afectado.cliente_numero_documento, hash: null }),
        entorno: empresa.entorno,
        clave_idempotencia: clave,
      });
      await insertarItems(c, id, lineas, totales);
      await registrarAuditoria(c, { usuarioId: usuario.id, accion: 'comprobante.nota', entidad: 'comprobantes', entidadId: id, detalle: { huella } });
      if (estado === 'pendiente') await encolar(c, 'enviar_comprobante', { comprobante_id: id });
      return { comprobante: (await comprobanteCompleto(c, id))!, repetido: false };
    });
  } catch (error) {
    return traducirConflictos(error);
  }
}
