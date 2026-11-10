import 'package:decimal/decimal.dart';

import 'catalogo_pos.dart';
import 'dinero.dart';

final Decimal icbperPorUnidad = Decimal.parse('0.50');

class LineaCarrito {
  LineaCarrito({
    required this.producto,
    required this.cantidad,
    Decimal? descuento,
  }) : descuento = descuento ?? cero;

  final ProductoPos producto;
  final Decimal cantidad;
  final Decimal descuento;

  Decimal get bruto => redondear2(cantidad * producto.precio);

  Decimal get importeNeto => bruto - descuento;

  LineaCarrito conCantidad(Decimal nueva) {
    final lineaNueva = LineaCarrito(producto: producto, cantidad: nueva);
    final tope = lineaNueva.bruto;
    return LineaCarrito(
      producto: producto,
      cantidad: nueva,
      descuento: descuento > tope ? tope : descuento,
    );
  }

  LineaCarrito conDescuento(Decimal nuevo) {
    if (nuevo < cero || nuevo > bruto) {
      throw ArgumentError.value(nuevo, 'descuento');
    }
    return LineaCarrito(
      producto: producto,
      cantidad: cantidad,
      descuento: redondear2(nuevo),
    );
  }
}

class TotalesCarrito {
  const TotalesCarrito({
    required this.descuento,
    required this.base,
    required this.igv,
    required this.icbper,
    required this.total,
  });

  final Decimal descuento;
  final Decimal base;
  final Decimal igv;
  final Decimal icbper;
  final Decimal total;
}

class Carrito {
  const Carrito([this.lineas = const []]);

  final List<LineaCarrito> lineas;

  bool get vacio => lineas.isEmpty;

  Decimal get unidades =>
      lineas.fold(cero, (suma, linea) => suma + linea.cantidad);

  Decimal cantidadDe(String productoId) {
    for (final linea in lineas) {
      if (linea.producto.id == productoId) return linea.cantidad;
    }
    return cero;
  }

  Carrito agregar(ProductoPos producto, [Decimal? cantidad]) {
    final sumar = cantidad ?? Decimal.one;
    if (sumar <= cero) return this;
    final indice = lineas.indexWhere((l) => l.producto.id == producto.id);
    if (indice < 0) {
      return Carrito([
        ...lineas,
        LineaCarrito(producto: producto, cantidad: sumar),
      ]);
    }
    final copia = [...lineas];
    copia[indice] = copia[indice].conCantidad(copia[indice].cantidad + sumar);
    return Carrito(copia);
  }

  Carrito fijarCantidad(String productoId, Decimal cantidad) {
    final redondeada = cantidad.round(scale: 4);
    if (redondeada <= cero) return quitar(productoId);
    return Carrito([
      for (final linea in lineas)
        if (linea.producto.id == productoId)
          linea.conCantidad(redondeada)
        else
          linea,
    ]);
  }

  Carrito fijarDescuento(String productoId, Decimal descuento) => Carrito([
    for (final linea in lineas)
      if (linea.producto.id == productoId)
        linea.conDescuento(descuento)
      else
        linea,
  ]);

  Carrito quitar(String productoId) => Carrito([
    for (final linea in lineas)
      if (linea.producto.id != productoId) linea,
  ]);

  TotalesCarrito totales(ConfiguracionFiscal fiscal) {
    var descuento = cero;
    var base = cero;
    var igv = cero;
    var icbper = cero;
    var total = cero;
    final divisor = Decimal.one + fiscal.factor;
    for (final linea in lineas) {
      final neto = linea.importeNeto;
      descuento += linea.descuento;
      final icbperLinea = linea.producto.aplicaIcbper
          ? redondear2(linea.cantidad * icbperPorUnidad)
          : cero;
      icbper += icbperLinea;
      if (linea.producto.afectacion != '10') {
        base += neto;
        total += neto + icbperLinea;
      } else if (fiscal.preciosIncluyenIgv) {
        final baseLinea = redondear2(dividir(neto, divisor));
        base += baseLinea;
        igv += neto - baseLinea;
        total += neto + icbperLinea;
      } else {
        final igvLinea = redondear2(neto * fiscal.factor);
        base += neto;
        igv += igvLinea;
        total += neto + igvLinea + icbperLinea;
      }
    }
    return TotalesCarrito(
      descuento: descuento,
      base: base,
      igv: igv,
      icbper: icbper,
      total: total,
    );
  }
}
