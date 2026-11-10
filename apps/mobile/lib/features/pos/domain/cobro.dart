import 'dart:convert';

import 'package:decimal/decimal.dart';

import 'carrito.dart';
import 'dinero.dart';

enum TipoDocumentoVenta {
  boleta('03', 'Boleta'),
  factura('01', 'Factura'),
  notaVenta('NV', 'Nota de venta');

  const TipoDocumentoVenta(this.codigo, this.etiqueta);
  final String codigo;
  final String etiqueta;
}

enum MedioPago {
  efectivo('Efectivo'),
  yape('Yape'),
  plin('Plin'),
  transferencia('Transferencia'),
  tarjeta('Tarjeta'),
  deposito('Depósito'),
  otro('Otro');

  const MedioPago(this.etiqueta);
  final String etiqueta;

  static MedioPago? desdeCodigo(String codigo) =>
      MedioPago.values.asNameMap()[codigo];
}

const tipoDocumentoDni = '1';
const tipoDocumentoRuc = '6';
const tipoDocumentoSinDocumento = '0';

final Decimal topeBoletaSinDocumento = Decimal.fromInt(700);

const _desfaseLima = Duration(hours: 5);

String fechaEnLima(DateTime instante) {
  final lima = instante.toUtc().subtract(_desfaseLima);
  final mes = lima.month.toString().padLeft(2, '0');
  final dia = lima.day.toString().padLeft(2, '0');
  return '${lima.year}-$mes-$dia';
}

class ClientePos {
  const ClientePos({
    required this.tipoDocumento,
    required this.numeroDocumento,
    required this.nombre,
    this.id,
    this.direccion,
    this.telefono,
  });

  ClientePos copiar({String? nombre, String? telefono}) => ClientePos(
    id: id,
    tipoDocumento: tipoDocumento,
    numeroDocumento: numeroDocumento,
    nombre: nombre ?? this.nombre,
    direccion: direccion,
    telefono: telefono ?? this.telefono,
  );

  factory ClientePos.fromJson(Map<String, dynamic> json) => ClientePos(
    id: json['id'] as String?,
    tipoDocumento:
        json['tipo_documento'] as String? ?? tipoDocumentoSinDocumento,
    numeroDocumento: json['numero_documento'] as String? ?? '',
    nombre: json['nombre'] as String? ?? '',
    direccion: json['direccion'] as String?,
    telefono: json['telefono'] as String?,
  );

  final String? id;
  final String tipoDocumento;
  final String numeroDocumento;
  final String nombre;
  final String? direccion;
  final String? telefono;

  bool get tieneDocumento =>
      tipoDocumento != tipoDocumentoSinDocumento && numeroDocumento.isNotEmpty;

  bool get esRucValido =>
      tipoDocumento == tipoDocumentoRuc &&
      RegExp(r'^\d{11}$').hasMatch(numeroDocumento);

  Map<String, dynamic> toCuerpo() => {
    'tipo_documento': tipoDocumento,
    'numero_documento': numeroDocumento,
    'nombre': nombre,
    if (direccion != null && direccion!.isNotEmpty) 'direccion': direccion,
  };
}

const clienteVarios = ClientePos(
  tipoDocumento: tipoDocumentoSinDocumento,
  numeroDocumento: '00000000',
  nombre: 'CLIENTES VARIOS',
);

class PagoCobro {
  const PagoCobro({required this.medio, required this.monto, this.referencia});

  final MedioPago medio;
  final Decimal monto;
  final String? referencia;

  Map<String, dynamic> toCuerpo() => {
    'medio': medio.name,
    'monto': importe(monto),
    if (referencia != null && referencia!.trim().isNotEmpty)
      'referencia': referencia!.trim(),
  };
}

class ResumenPagos {
  ResumenPagos(this.pagos, this.total);

  final List<PagoCobro> pagos;
  final Decimal total;

  Decimal get recibido => pagos.fold(cero, (suma, p) => suma + p.monto);

  Decimal get efectivo => pagos
      .where((p) => p.medio == MedioPago.efectivo)
      .fold(cero, (suma, p) => suma + p.monto);

  Decimal get faltante => recibido >= total ? cero : total - recibido;

  Decimal get exceso => recibido > total ? recibido - total : cero;

  Decimal get vuelto => exceso > efectivo ? efectivo : exceso;

  bool get excesoSinEfectivo => exceso > efectivo;

  bool get cubreTotal => faltante == cero && !excesoSinEfectivo;
}

class SolicitudCobro {
  const SolicitudCobro({
    required this.tipo,
    required this.carrito,
    required this.pagos,
    this.cliente,
    this.fechaEmision,
  });

  final TipoDocumentoVenta tipo;
  final Carrito carrito;
  final List<PagoCobro> pagos;
  final ClientePos? cliente;
  final String? fechaEmision;

  ClientePos get clienteEfectivo => cliente ?? clienteVarios;

  Map<String, dynamic> cuerpo() {
    final receptor = clienteEfectivo;
    return {
      'tipo': tipo.codigo,
      if (receptor.id != null)
        'cliente_id': receptor.id
      else
        'cliente': receptor.toCuerpo(),
      'items': [
        for (final linea in carrito.lineas)
          {
            'producto_id': linea.producto.id,
            'descripcion': linea.producto.nombre,
            'unidad': linea.producto.unidad,
            'cantidad': linea.cantidad.toString(),
            'precio_unitario': linea.producto.precio.toString(),
            'descuento': importe(linea.descuento),
            'afectacion': linea.producto.afectacion,
          },
      ],
      'pagos': [for (final pago in pagos) pago.toCuerpo()],
      'forma_pago': 'contado',
      if (fechaEmision != null) 'fecha_emision': fechaEmision,
    };
  }

  String huella() => jsonEncode(cuerpo());

  String? validarCliente(Decimal total) {
    final receptor = clienteEfectivo;
    if (tipo == TipoDocumentoVenta.factura && !receptor.esRucValido) {
      return 'La factura exige un cliente con RUC de 11 dígitos.';
    }
    if (tipo == TipoDocumentoVenta.boleta &&
        !receptor.tieneDocumento &&
        total > topeBoletaSinDocumento) {
      return 'Una boleta de más de S/ 700 exige el documento del cliente.';
    }
    return null;
  }

  String? validar(Decimal total) {
    if (carrito.vacio) return 'Agrega productos al carrito.';
    final errorCliente = validarCliente(total);
    if (errorCliente != null) return errorCliente;
    if (pagos.isEmpty) return 'Registra al menos un pago.';
    if (pagos.any((p) => p.monto <= cero)) {
      return 'Cada pago debe ser mayor que cero.';
    }
    final resumen = ResumenPagos(pagos, total);
    if (resumen.faltante > cero) {
      return 'Faltan ${soles(resumen.faltante)} por cubrir.';
    }
    if (resumen.excesoSinEfectivo) {
      return 'Solo el efectivo puede dar vuelto. Ajusta los montos.';
    }
    return null;
  }
}

class Previsualizacion {
  const Previsualizacion({
    required this.opGravadas,
    required this.opExoneradas,
    required this.opInafectas,
    required this.descuentoTotal,
    required this.igv,
    required this.icbper,
    required this.total,
    this.estimada = false,
  });

  factory Previsualizacion.fromJson(Map<String, dynamic> json) {
    final datos = json['totales'] is Map
        ? Map<String, dynamic>.from(json['totales'] as Map)
        : json;
    return Previsualizacion(
      opGravadas: decimalDe(datos['op_gravadas']),
      opExoneradas: decimalDe(datos['op_exoneradas']),
      opInafectas: decimalDe(datos['op_inafectas']),
      descuentoTotal: decimalDe(datos['descuento_total']),
      igv: decimalDe(datos['igv']),
      icbper: decimalDe(datos['icbper']),
      total: decimalDe(datos['total']),
    );
  }

  factory Previsualizacion.estimadaDe(
    TotalesCarrito totales, {
    bool estimada = true,
  }) => Previsualizacion(
    opGravadas: totales.base,
    opExoneradas: cero,
    opInafectas: cero,
    descuentoTotal: totales.descuento,
    igv: totales.igv,
    icbper: totales.icbper,
    total: totales.total,
    estimada: estimada,
  );

  final Decimal opGravadas;
  final Decimal opExoneradas;
  final Decimal opInafectas;
  final Decimal descuentoTotal;
  final Decimal igv;
  final Decimal icbper;
  final Decimal total;
  final bool estimada;
}
