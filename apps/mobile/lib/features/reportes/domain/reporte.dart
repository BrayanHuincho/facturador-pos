import 'package:decimal/decimal.dart';
import 'package:facturador_pos/features/comprobantes/domain/importes.dart';
import 'package:facturador_pos/features/pos/domain/cobro.dart';

enum Agrupacion {
  dia('dia', 'Día'),
  producto('producto', 'Producto'),
  medio('medio', 'Medio'),
  usuario('usuario', 'Usuario');

  const Agrupacion(this.codigo, this.etiqueta);

  final String codigo;
  final String etiqueta;
}

class KpisReporte {
  const KpisReporte({
    required this.ventasBrutas,
    required this.notasCredito,
    required this.notasDebito,
    required this.ventasNetas,
    required this.igv,
    required this.documentosVenta,
    required this.ticketPromedio,
  });

  factory KpisReporte.desdeJson(Map<String, dynamic> json) => KpisReporte(
    ventasBrutas: decimalDe(json['ventas_brutas']),
    notasCredito: decimalDe(json['notas_credito']),
    notasDebito: decimalDe(json['notas_debito']),
    ventasNetas: decimalDe(json['ventas_netas']),
    igv: decimalDe(json['igv']),
    documentosVenta: (json['documentos_venta'] as num?)?.toInt() ?? 0,
    ticketPromedio: decimalDe(json['ticket_promedio']),
  );

  final Decimal ventasBrutas;
  final Decimal notasCredito;
  final Decimal notasDebito;
  final Decimal ventasNetas;
  final Decimal igv;
  final int documentosVenta;
  final Decimal ticketPromedio;
}

class FilaVenta {
  const FilaVenta({
    required this.etiqueta,
    required this.total,
    required this.documentos,
  });

  factory FilaVenta.desdeJson(Map<String, dynamic> json) => FilaVenta(
    etiqueta: (json['etiqueta'] ?? json['medio'] ?? json['clave'] ?? '-')
        .toString(),
    total: decimalDe(json['total']),
    documentos: (json['documentos'] as num?)?.toInt() ?? 0,
  );

  final String etiqueta;
  final Decimal total;
  final int documentos;
}

FilaVenta etiquetaFilaMedio(FilaVenta fila) => FilaVenta(
  etiqueta: MedioPago.desdeCodigo(fila.etiqueta)?.etiqueta ?? fila.etiqueta,
  total: fila.total,
  documentos: fila.documentos,
);
