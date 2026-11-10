import 'package:decimal/decimal.dart';

import 'dinero.dart';

class CategoriaPos {
  const CategoriaPos({required this.id, required this.nombre});

  factory CategoriaPos.fromJson(Map<String, dynamic> json) => CategoriaPos(
    id: json['id'] as String,
    nombre: json['nombre'] as String? ?? '',
  );

  final String id;
  final String nombre;

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre};
}

class ProductoPos {
  const ProductoPos({
    required this.id,
    required this.nombre,
    required this.precio,
    this.codigo,
    this.codigoBarras,
    this.categoriaId,
    this.unidad = 'NIU',
    this.afectacion = '10',
    this.aplicaIcbper = false,
    this.controlaStock = false,
    this.imagenPath,
    this.stock,
  });

  factory ProductoPos.fromJson(Map<String, dynamic> json) => ProductoPos(
    id: json['id'] as String,
    nombre: json['nombre'] as String? ?? '',
    precio: decimalDe(json['precio']),
    codigo: json['codigo'] as String?,
    codigoBarras: json['codigo_barras'] as String?,
    categoriaId: json['categoria_id'] as String?,
    unidad: json['unidad'] as String? ?? 'NIU',
    afectacion: json['afectacion'] as String? ?? '10',
    aplicaIcbper: json['aplica_icbper'] as bool? ?? false,
    controlaStock: json['controla_stock'] as bool? ?? false,
    imagenPath: json['imagen_path'] as String?,
    stock: json['stock'] == null ? null : decimalDe(json['stock']),
  );

  final String id;
  final String nombre;
  final Decimal precio;
  final String? codigo;
  final String? codigoBarras;
  final String? categoriaId;
  final String unidad;
  final String afectacion;
  final bool aplicaIcbper;
  final bool controlaStock;
  final String? imagenPath;
  final Decimal? stock;

  bool get sinStock => controlaStock && stock != null && stock! <= cero;

  bool coincide(String consulta) {
    final texto = consulta.trim().toLowerCase();
    if (texto.isEmpty) return true;
    return nombre.toLowerCase().contains(texto) ||
        (codigo ?? '').toLowerCase().contains(texto) ||
        (codigoBarras ?? '').toLowerCase() == texto;
  }

  bool tieneCodigo(String valor) {
    final texto = valor.trim();
    return texto.isNotEmpty && (codigoBarras == texto || codigo == texto);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'precio': precio.toString(),
    'codigo': codigo,
    'codigo_barras': codigoBarras,
    'categoria_id': categoriaId,
    'unidad': unidad,
    'afectacion': afectacion,
    'aplica_icbper': aplicaIcbper,
    'controla_stock': controlaStock,
    'imagen_path': imagenPath,
    'stock': stock?.toString(),
  };
}

class ConfiguracionFiscal {
  const ConfiguracionFiscal({
    required this.igvPorcentaje,
    required this.preciosIncluyenIgv,
  });

  factory ConfiguracionFiscal.porDefecto() => ConfiguracionFiscal(
    igvPorcentaje: Decimal.fromInt(18),
    preciosIncluyenIgv: true,
  );

  factory ConfiguracionFiscal.fromJson(Map<String, dynamic> json) =>
      ConfiguracionFiscal(
        igvPorcentaje: json['igv_porcentaje'] == null
            ? Decimal.fromInt(18)
            : decimalDe(json['igv_porcentaje']),
        preciosIncluyenIgv: json['precios_incluyen_igv'] as bool? ?? true,
      );

  final Decimal igvPorcentaje;
  final bool preciosIncluyenIgv;

  Decimal get factor => dividir(igvPorcentaje, cien);

  Map<String, dynamic> toJson() => {
    'igv_porcentaje': igvPorcentaje.toString(),
    'precios_incluyen_igv': preciosIncluyenIgv,
  };
}

class Catalogo {
  const Catalogo({
    required this.categorias,
    required this.productos,
    required this.fiscal,
    this.desdeCache = false,
  });

  final List<CategoriaPos> categorias;
  final List<ProductoPos> productos;
  final ConfiguracionFiscal fiscal;
  final bool desdeCache;
}
