import 'package:decimal/decimal.dart';
import 'package:facturador_pos/features/comprobantes/domain/importes.dart';

class Turno {
  const Turno({
    required this.id,
    required this.estado,
    required this.abiertoEn,
    required this.cerradoEn,
    required this.montoApertura,
    required this.montoEsperado,
    required this.montoContado,
    required this.diferencia,
    required this.observacion,
  });

  factory Turno.desdeFila(Map<String, dynamic> fila) => Turno(
    id: fila['id'] as String,
    estado: fila['estado'] as String? ?? '',
    abiertoEn: DateTime.tryParse(fila['abierto_en']?.toString() ?? ''),
    cerradoEn: DateTime.tryParse(fila['cerrado_en']?.toString() ?? ''),
    montoApertura: decimalDe(fila['monto_apertura']),
    montoEsperado: decimalOpcional(fila['monto_esperado']),
    montoContado: decimalOpcional(fila['monto_contado']),
    diferencia: decimalOpcional(fila['diferencia']),
    observacion: fila['observacion'] as String?,
  );

  final String id;
  final String estado;
  final DateTime? abiertoEn;
  final DateTime? cerradoEn;
  final Decimal montoApertura;
  final Decimal? montoEsperado;
  final Decimal? montoContado;
  final Decimal? diferencia;
  final String? observacion;
}

class TotalMedio {
  const TotalMedio(this.medio, this.total);

  final String medio;
  final Decimal total;
}

class ResumenTurno {
  const ResumenTurno({
    required this.montoApertura,
    required this.ventasEfectivo,
    required this.vuelto,
    required this.ingresos,
    required this.egresos,
    required this.montoEsperado,
    required this.totalVentas,
    required this.porMedio,
  });

  factory ResumenTurno.desdeJson(Map<String, dynamic> json) => ResumenTurno(
    montoApertura: decimalDe(json['monto_apertura']),
    ventasEfectivo: decimalDe(json['ventas_efectivo']),
    vuelto: decimalDe(json['vuelto']),
    ingresos: decimalDe(json['ingresos']),
    egresos: decimalDe(json['egresos']),
    montoEsperado: decimalDe(json['monto_esperado']),
    totalVentas: decimalDe(json['total_ventas']),
    porMedio: ((json['por_medio'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (fila) =>
              TotalMedio(fila['medio'] as String, decimalDe(fila['total'])),
        )
        .toList(),
  );

  final Decimal montoApertura;
  final Decimal ventasEfectivo;
  final Decimal vuelto;
  final Decimal ingresos;
  final Decimal egresos;
  final Decimal montoEsperado;
  final Decimal totalVentas;
  final List<TotalMedio> porMedio;
}

class TurnoConResumen {
  const TurnoConResumen(this.turno, this.resumen);

  factory TurnoConResumen.desdeJson(Map<String, dynamic> json) =>
      TurnoConResumen(
        Turno.desdeFila(json['turno'] as Map<String, dynamic>),
        ResumenTurno.desdeJson(json['resumen'] as Map<String, dynamic>),
      );

  final Turno turno;
  final ResumenTurno resumen;
}

class MovimientoCaja {
  const MovimientoCaja({
    required this.id,
    required this.tipo,
    required this.monto,
    required this.concepto,
    required this.creadoEn,
  });

  factory MovimientoCaja.desdeFila(Map<String, dynamic> fila) => MovimientoCaja(
    id: fila['id'] as String,
    tipo: fila['tipo'] as String? ?? 'ingreso',
    monto: decimalDe(fila['monto']),
    concepto: fila['concepto'] as String? ?? '',
    creadoEn: DateTime.tryParse(fila['creado_en']?.toString() ?? ''),
  );

  final String id;
  final String tipo;
  final Decimal monto;
  final String concepto;
  final DateTime? creadoEn;

  bool get esIngreso => tipo == 'ingreso';
}
