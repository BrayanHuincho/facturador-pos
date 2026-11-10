import 'package:decimal/decimal.dart';

import 'importes.dart';

enum EstadoDocumento {
  pendiente('pendiente', 'Pendiente'),
  enviando('enviando', 'Enviando'),
  procesando('procesando', 'Procesando'),
  aceptado('aceptado', 'Aceptado'),
  observado('observado', 'Observado'),
  rechazado('rechazado', 'Rechazado'),
  error('error', 'Error'),
  porResumen('por_resumen', 'Por resumen'),
  porAnular('por_anular', 'Por anular'),
  anulado('anulado', 'Anulado'),
  noAplica('no_aplica', 'Sin envío'),
  desconocido('', 'Desconocido');

  const EstadoDocumento(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;

  static EstadoDocumento desde(Object? codigo) => values.firstWhere(
    (estado) => estado.codigo == codigo,
    orElse: () => desconocido,
  );

  static List<EstadoDocumento> get filtrables => values
      .where(
        (estado) =>
            estado != desconocido && estado != EstadoDocumento.procesando,
      )
      .toList();
}

const Map<String, String> tiposComprobante = {
  '01': 'Factura',
  '03': 'Boleta',
  '07': 'Nota de crédito',
  '08': 'Nota de débito',
  'NV': 'Nota de venta',
};

const Map<String, String> motivosNotaCredito = {
  '01': 'Anulación de la operación',
  '02': 'Anulación por error en el RUC',
  '03': 'Corrección por error en la descripción',
  '04': 'Descuento global',
  '05': 'Descuento por ítem',
  '06': 'Devolución total',
  '07': 'Devolución por ítem',
  '08': 'Bonificación',
  '09': 'Disminución en el valor',
  '10': 'Otros conceptos',
  '13': 'Ajuste de montos o fechas de pago',
};

const Map<String, String> motivosNotaDebito = {
  '01': 'Intereses por mora',
  '02': 'Aumento en el valor',
  '03': 'Penalidades u otros conceptos',
};

const Set<String> motivosCreditoTotales = {'01', '02', '06'};

const int diasPlazoAnulacion = 7;

class ItemComprobante {
  const ItemComprobante({
    required this.productoId,
    required this.orden,
    required this.codigo,
    required this.descripcion,
    required this.unidad,
    required this.cantidad,
    required this.precioUnitario,
    required this.afectacion,
    required this.total,
  });

  factory ItemComprobante.desdeFila(Map<String, dynamic> fila) =>
      ItemComprobante(
        productoId: fila['producto_id'] as String?,
        orden: (fila['orden'] as num?)?.toInt() ?? 0,
        codigo: fila['codigo'] as String?,
        descripcion: fila['descripcion'] as String? ?? '',
        unidad: fila['unidad'] as String? ?? 'NIU',
        cantidad: decimalDe(fila['cantidad']),
        precioUnitario: decimalDe(fila['precio_unitario']),
        afectacion: fila['afectacion']?.toString(),
        total: decimalDe(fila['total']),
      );

  final String? productoId;
  final int orden;
  final String? codigo;
  final String descripcion;
  final String unidad;
  final Decimal cantidad;
  final Decimal precioUnitario;
  final String? afectacion;
  final Decimal total;
}

class PagoComprobante {
  const PagoComprobante({required this.medio, required this.monto});

  factory PagoComprobante.desdeFila(Map<String, dynamic> fila) =>
      PagoComprobante(
        medio: fila['medio'] as String? ?? 'otro',
        monto: decimalDe(fila['monto']),
      );

  final String medio;
  final Decimal monto;
}

class Comprobante {
  const Comprobante({
    required this.id,
    required this.tipo,
    required this.serie,
    required this.correlativo,
    required this.fechaEmision,
    required this.horaEmision,
    required this.moneda,
    required this.formaPago,
    required this.clienteNombre,
    required this.clienteNumeroDocumento,
    required this.opGravadas,
    required this.opExoneradas,
    required this.opInafectas,
    required this.opGratuitas,
    required this.descuentoTotal,
    required this.igv,
    required this.icbper,
    required this.total,
    required this.estado,
    required this.sunatCodigo,
    required this.sunatDescripcion,
    required this.sunatNotas,
    required this.hash,
    required this.xmlPath,
    required this.cdrPath,
    required this.entorno,
    required this.intentos,
    required this.afectadoSerie,
    required this.afectadoCorrelativo,
    required this.motivoDescripcion,
    required this.items,
    required this.pagos,
  });

  factory Comprobante.desdeFila(Map<String, dynamic> fila) {
    final items =
        ((fila['comprobante_items'] as List?) ?? const [])
            .cast<Map<String, dynamic>>()
            .map(ItemComprobante.desdeFila)
            .toList()
          ..sort((a, b) => a.orden.compareTo(b.orden));
    return Comprobante(
      id: fila['id'] as String,
      tipo: fila['tipo'] as String? ?? '',
      serie: fila['serie'] as String? ?? '',
      correlativo: (fila['correlativo'] as num?)?.toInt() ?? 0,
      fechaEmision: fila['fecha_emision'] as String? ?? '',
      horaEmision: fila['hora_emision'] as String?,
      moneda: fila['moneda'] as String? ?? 'PEN',
      formaPago: fila['forma_pago'] as String?,
      clienteNombre: fila['cliente_nombre'] as String? ?? 'Clientes varios',
      clienteNumeroDocumento: fila['cliente_numero_documento'] as String?,
      opGravadas: decimalDe(fila['op_gravadas']),
      opExoneradas: decimalDe(fila['op_exoneradas']),
      opInafectas: decimalDe(fila['op_inafectas']),
      opGratuitas: decimalDe(fila['op_gratuitas']),
      descuentoTotal: decimalDe(fila['descuento_total']),
      igv: decimalDe(fila['igv']),
      icbper: decimalDe(fila['icbper']),
      total: decimalDe(fila['total']),
      estado: EstadoDocumento.desde(fila['estado']),
      sunatCodigo: fila['sunat_codigo']?.toString(),
      sunatDescripcion: fila['sunat_descripcion'] as String?,
      sunatNotas: _notasDesde(fila['sunat_notas']),
      hash: fila['hash'] as String?,
      xmlPath: fila['xml_path'] as String?,
      cdrPath: fila['cdr_path'] as String?,
      entorno: fila['entorno'] as String?,
      intentos: (fila['intentos'] as num?)?.toInt() ?? 0,
      afectadoSerie: fila['afectado_serie'] as String?,
      afectadoCorrelativo: (fila['afectado_correlativo'] as num?)?.toInt(),
      motivoDescripcion: fila['motivo_descripcion'] as String?,
      items: items,
      pagos: ((fila['pagos'] as List?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(PagoComprobante.desdeFila)
          .toList(),
    );
  }

  static List<String> _notasDesde(Object? notas) {
    if (notas is List) return notas.map((nota) => nota.toString()).toList();
    if (notas == null) return const [];
    return [notas.toString()];
  }

  final String id;
  final String tipo;
  final String serie;
  final int correlativo;
  final String fechaEmision;
  final String? horaEmision;
  final String moneda;
  final String? formaPago;
  final String clienteNombre;
  final String? clienteNumeroDocumento;
  final Decimal opGravadas;
  final Decimal opExoneradas;
  final Decimal opInafectas;
  final Decimal opGratuitas;
  final Decimal descuentoTotal;
  final Decimal igv;
  final Decimal icbper;
  final Decimal total;
  final EstadoDocumento estado;
  final String? sunatCodigo;
  final String? sunatDescripcion;
  final List<String> sunatNotas;
  final String? hash;
  final String? xmlPath;
  final String? cdrPath;
  final String? entorno;
  final int intentos;
  final String? afectadoSerie;
  final int? afectadoCorrelativo;
  final String? motivoDescripcion;
  final List<ItemComprobante> items;
  final List<PagoComprobante> pagos;

  String get numero => '$serie-$correlativo';
  String get tipoEtiqueta => tiposComprobante[tipo] ?? tipo;
  bool get esNotaDeVenta => tipo == 'NV';
  bool get admiteNotas =>
      (tipo == '01' || tipo == '03') &&
      (estado == EstadoDocumento.aceptado ||
          estado == EstadoDocumento.observado);
  bool get puedeReenviar =>
      estado == EstadoDocumento.error || estado == EstadoDocumento.pendiente;
  bool get puedeConsultar =>
      !esNotaDeVenta &&
      const {
        EstadoDocumento.pendiente,
        EstadoDocumento.enviando,
        EstadoDocumento.error,
        EstadoDocumento.aceptado,
        EstadoDocumento.observado,
        EstadoDocumento.rechazado,
      }.contains(estado);

  bool get dentroDePlazoAnulacion {
    final emision = DateTime.tryParse(fechaEmision);
    if (emision == null) return false;
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    return hoy.difference(emision).inDays <= diasPlazoAnulacion;
  }

  bool get estadoAnulable => esNotaDeVenta
      ? estado == EstadoDocumento.noAplica
      : const {
          EstadoDocumento.aceptado,
          EstadoDocumento.observado,
          EstadoDocumento.porResumen,
        }.contains(estado);

  bool get puedeAnular =>
      estadoAnulable && (esNotaDeVenta || dentroDePlazoAnulacion);
  bool get requiereNotaParaAnular =>
      estadoAnulable && !esNotaDeVenta && !dentroDePlazoAnulacion;
}

class FiltrosComprobantes {
  const FiltrosComprobantes({
    this.tipo,
    this.estado,
    this.desde,
    this.hasta,
    this.busqueda = '',
  });

  final String? tipo;
  final EstadoDocumento? estado;
  final String? desde;
  final String? hasta;
  final String busqueda;

  bool get activos =>
      tipo != null || estado != null || desde != null || hasta != null;

  static final RegExp patronNumero = RegExp(r'^([A-Za-z0-9]{4})-(\d+)$');

  bool coincide(Comprobante c) {
    if (tipo != null && c.tipo != tipo) return false;
    if (estado != null && c.estado != estado) return false;
    if (desde != null && c.fechaEmision.compareTo(desde!) < 0) return false;
    if (hasta != null && c.fechaEmision.compareTo(hasta!) > 0) return false;
    final termino = busqueda.trim().toLowerCase();
    if (termino.isEmpty) return true;
    return c.numero.toLowerCase().contains(termino) ||
        c.clienteNombre.toLowerCase().contains(termino) ||
        (c.clienteNumeroDocumento ?? '').contains(termino);
  }
}

class ProcesoSunat {
  const ProcesoSunat({
    required this.id,
    required this.identificador,
    required this.fecha,
    required this.estado,
    required this.ticket,
    required this.sunatDescripcion,
  });

  factory ProcesoSunat.desdeFila(Map<String, dynamic> fila) => ProcesoSunat(
    id: fila['id'] as String,
    identificador: fila['identificador'] as String? ?? '',
    fecha: fila['fecha_referencia'] as String? ?? '',
    estado: fila['estado'] as String? ?? '',
    ticket: fila['ticket']?.toString(),
    sunatDescripcion: fila['sunat_descripcion'] as String?,
  );

  final String id;
  final String identificador;
  final String fecha;
  final String estado;
  final String? ticket;
  final String? sunatDescripcion;
}
