import 'package:decimal/decimal.dart';

import '../../../core/formatos/formatos.dart';

Decimal? decimalOpcional(Object? valor) =>
    valor == null ? null : parseDecimal(valor);

class Categoria {
  const Categoria({
    required this.id,
    required this.nombre,
    required this.orden,
    required this.activa,
  });

  final String id;
  final String nombre;
  final int orden;
  final bool activa;

  factory Categoria.desdeJson(Map<String, dynamic> json) => Categoria(
    id: json['id'] as String,
    nombre: json['nombre'] as String? ?? '',
    orden: (json['orden'] as num?)?.toInt() ?? 0,
    activa: json['activa'] as bool? ?? true,
  );
}

class Producto {
  const Producto({
    required this.id,
    required this.codigo,
    required this.codigoBarras,
    required this.nombre,
    required this.descripcion,
    required this.categoriaId,
    required this.unidad,
    required this.precio,
    required this.costo,
    required this.afectacion,
    required this.aplicaIcbper,
    required this.controlaStock,
    required this.stockMinimo,
    required this.imagenPath,
    required this.activo,
  });

  final String id;
  final String? codigo;
  final String? codigoBarras;
  final String nombre;
  final String? descripcion;
  final String? categoriaId;
  final String unidad;
  final Decimal precio;
  final Decimal? costo;
  final String afectacion;
  final bool aplicaIcbper;
  final bool controlaStock;
  final Decimal? stockMinimo;
  final String? imagenPath;
  final bool activo;

  factory Producto.desdeJson(Map<String, dynamic> json) => Producto(
    id: json['id'] as String,
    codigo: json['codigo'] as String?,
    codigoBarras: json['codigo_barras'] as String?,
    nombre: json['nombre'] as String? ?? '',
    descripcion: json['descripcion'] as String?,
    categoriaId: json['categoria_id'] as String?,
    unidad: json['unidad'] as String? ?? 'NIU',
    precio: parseDecimal(json['precio']),
    costo: decimalOpcional(json['costo']),
    afectacion: json['afectacion'] as String? ?? '10',
    aplicaIcbper: json['aplica_icbper'] as bool? ?? false,
    controlaStock: json['controla_stock'] as bool? ?? false,
    stockMinimo: decimalOpcional(json['stock_minimo']),
    imagenPath: json['imagen_path'] as String?,
    activo: json['activo'] as bool? ?? true,
  );
}

class StockLocal {
  const StockLocal({
    required this.establecimientoId,
    required this.establecimientoNombre,
    required this.cantidad,
  });

  final String establecimientoId;
  final String establecimientoNombre;
  final Decimal cantidad;
}

class Cliente {
  const Cliente({
    required this.id,
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.nombre,
    required this.direccion,
    required this.ubigeo,
    required this.telefono,
    required this.correo,
    required this.activo,
  });

  final String id;
  final String tipoDocumento;
  final String numeroDocumento;
  final String nombre;
  final String? direccion;
  final String? ubigeo;
  final String? telefono;
  final String? correo;
  final bool activo;

  factory Cliente.desdeJson(Map<String, dynamic> json) => Cliente(
    id: json['id'] as String,
    tipoDocumento: json['tipo_documento'] as String? ?? '0',
    numeroDocumento: json['numero_documento'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    direccion: json['direccion'] as String?,
    ubigeo: json['ubigeo'] as String?,
    telefono: json['telefono'] as String?,
    correo: json['correo'] as String?,
    activo: json['activo'] as bool? ?? true,
  );
}

class DocumentoConsultado {
  const DocumentoConsultado({
    required this.nombre,
    required this.direccion,
    required this.ubigeo,
  });

  final String nombre;
  final String? direccion;
  final String? ubigeo;

  factory DocumentoConsultado.desdeJson(Map<String, dynamic> json) =>
      DocumentoConsultado(
        nombre: json['razon_social'] as String? ?? '',
        direccion: json['direccion'] as String?,
        ubigeo: json['ubigeo'] as String?,
      );
}

const Map<String, String> afectacionesIgv = {
  '10': 'Gravado',
  '20': 'Exonerado',
  '30': 'Inafecto',
};

const String tipoDocumentoSinDocumento = '0';
const String numeroSinDocumento = '00000000';
const String tipoDocumentoDni = '1';
const String tipoDocumentoRuc = '6';

const Map<String, String> tiposDocumentoCliente = {
  tipoDocumentoDni: 'DNI',
  tipoDocumentoRuc: 'RUC',
  '4': 'Carné de extranjería',
  '7': 'Pasaporte',
  tipoDocumentoSinDocumento: 'Sin documento',
};
