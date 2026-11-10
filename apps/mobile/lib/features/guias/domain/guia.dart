import 'package:decimal/decimal.dart';
import 'package:facturador_pos/features/comprobantes/domain/importes.dart';

const Map<String, String> motivosTraslado = {
  '01': 'Venta',
  '14': 'Venta sujeta a confirmación del comprador',
  '02': 'Compra',
  '04': 'Traslado entre establecimientos',
  '06': 'Devolución',
  '07': 'Recojo de bienes transformados',
  '05': 'Consignación',
  '17': 'Traslado para transformación',
  '13': 'Otros',
};

const Map<String, String> modalidadesTraslado = {
  '01': 'Transporte público',
  '02': 'Transporte privado',
};

const Map<String, String> tiposDocumentoDestinatario = {
  '6': 'RUC',
  '1': 'DNI',
  '4': 'Carné de extranjería',
  '7': 'Pasaporte',
};

class ItemGuia {
  const ItemGuia({
    required this.descripcion,
    required this.unidad,
    required this.cantidad,
  });

  factory ItemGuia.desdeFila(Map<String, dynamic> fila) => ItemGuia(
    descripcion: fila['descripcion'] as String? ?? '',
    unidad: fila['unidad'] as String? ?? 'NIU',
    cantidad: decimalDe(fila['cantidad']),
  );

  final String descripcion;
  final String unidad;
  final Decimal cantidad;
}

class Guia {
  const Guia({
    required this.id,
    required this.serie,
    required this.correlativo,
    required this.fechaEmision,
    required this.fechaTraslado,
    required this.motivoCodigo,
    required this.modalidad,
    required this.pesoTotal,
    required this.unidadPeso,
    required this.partidaDireccion,
    required this.llegadaDireccion,
    required this.destinatarioNombre,
    required this.destinatarioNumeroDocumento,
    required this.vehiculoPlaca,
    required this.estado,
    required this.ticket,
    required this.sunatCodigo,
    required this.sunatDescripcion,
    required this.items,
  });

  factory Guia.desdeFila(Map<String, dynamic> fila) => Guia(
    id: fila['id'] as String,
    serie: fila['serie'] as String? ?? '',
    correlativo: (fila['correlativo'] as num?)?.toInt() ?? 0,
    fechaEmision: fila['fecha_emision'] as String? ?? '',
    fechaTraslado: fila['fecha_traslado'] as String? ?? '',
    motivoCodigo: fila['motivo_codigo'] as String? ?? '',
    modalidad: fila['modalidad'] as String? ?? '',
    pesoTotal: decimalDe(fila['peso_total']),
    unidadPeso: fila['unidad_peso'] as String? ?? 'KGM',
    partidaDireccion: fila['partida_direccion'] as String? ?? '',
    llegadaDireccion: fila['llegada_direccion'] as String? ?? '',
    destinatarioNombre: fila['destinatario_nombre'] as String? ?? '',
    destinatarioNumeroDocumento:
        fila['destinatario_numero_documento'] as String? ?? '',
    vehiculoPlaca: fila['vehiculo_placa'] as String?,
    estado: fila['estado'] as String? ?? '',
    ticket: fila['ticket']?.toString(),
    sunatCodigo: fila['sunat_codigo']?.toString(),
    sunatDescripcion: fila['sunat_descripcion'] as String?,
    items: ((fila['guia_items'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ItemGuia.desdeFila)
        .toList(),
  );

  final String id;
  final String serie;
  final int correlativo;
  final String fechaEmision;
  final String fechaTraslado;
  final String motivoCodigo;
  final String modalidad;
  final Decimal pesoTotal;
  final String unidadPeso;
  final String partidaDireccion;
  final String llegadaDireccion;
  final String destinatarioNombre;
  final String destinatarioNumeroDocumento;
  final String? vehiculoPlaca;
  final String estado;
  final String? ticket;
  final String? sunatCodigo;
  final String? sunatDescripcion;
  final List<ItemGuia> items;

  String get numero => '$serie-$correlativo';
  bool get puedeReenviar => estado == 'error' || estado == 'pendiente';
  bool get tieneArchivos => estado == 'aceptado' || estado == 'observado';
}
