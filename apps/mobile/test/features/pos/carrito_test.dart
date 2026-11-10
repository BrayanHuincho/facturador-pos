import 'package:decimal/decimal.dart';
import 'package:facturador_pos/features/pos/domain/carrito.dart';
import 'package:facturador_pos/features/pos/domain/catalogo_pos.dart';
import 'package:facturador_pos/features/pos/domain/cobro.dart';
import 'package:flutter_test/flutter_test.dart';

Decimal d(String valor) => Decimal.parse(valor);

ProductoPos producto(
  String id,
  String precio, {
  String afectacion = '10',
  bool icbper = false,
}) => ProductoPos(
  id: id,
  nombre: 'Producto $id',
  precio: d(precio),
  afectacion: afectacion,
  aplicaIcbper: icbper,
);

void main() {
  final fiscal = ConfiguracionFiscal.porDefecto();

  group('Carrito', () {
    test('agregar el mismo producto acumula la cantidad', () {
      final carrito = const Carrito()
          .agregar(producto('a', '2.50'))
          .agregar(producto('a', '2.50'));
      expect(carrito.lineas, hasLength(1));
      expect(carrito.cantidadDe('a'), d('2'));
    });

    test('cantidad cero quita la linea', () {
      final carrito = const Carrito()
          .agregar(producto('a', '2.50'))
          .fijarCantidad('a', Decimal.zero);
      expect(carrito.vacio, isTrue);
    });

    test('calcula con precio incluido segun el contrato', () {
      final carrito = const Carrito().agregar(producto('a', '11.80'), d('2'));
      final totales = carrito.totales(fiscal);
      expect(totales.total, d('23.60'));
      expect(totales.base, d('20'));
      expect(totales.igv, d('3.60'));
    });

    test('redondea HALF_UP sin errores de coma flotante', () {
      final carrito = const Carrito().agregar(producto('a', '1.005'));
      expect(carrito.totales(fiscal).total, d('1.01'));
    });

    test('el descuento reduce la base y el igv', () {
      final carrito = const Carrito()
          .agregar(producto('a', '11.80'))
          .fijarDescuento('a', d('1.80'));
      final totales = carrito.totales(fiscal);
      expect(totales.total, d('10'));
      expect(totales.descuento, d('1.80'));
      expect(totales.base, d('8.47'));
      expect(totales.igv, d('1.53'));
    });

    test('rechaza un descuento mayor que el importe', () {
      final carrito = const Carrito().agregar(producto('a', '5'));
      expect(
        () => carrito.fijarDescuento('a', d('5.01')),
        throwsArgumentError,
      );
    });

    test('bajar la cantidad recorta el descuento al nuevo importe', () {
      final carrito = const Carrito()
          .agregar(producto('a', '5'), d('2'))
          .fijarDescuento('a', d('8'))
          .fijarCantidad('a', d('1'));
      expect(carrito.lineas.single.descuento, d('5'));
      expect(carrito.totales(fiscal).total, Decimal.zero);
    });

    test('exonerado no lleva igv e icbper suma 0.50 por unidad', () {
      final carrito = const Carrito()
          .agregar(producto('a', '10', afectacion: '20'))
          .agregar(producto('b', '1.18', icbper: true), d('2'));
      final totales = carrito.totales(fiscal);
      expect(totales.icbper, d('1'));
      expect(totales.total, d('13.36'));
    });

    test('la cantidad se limita a cuatro decimales', () {
      final carrito = const Carrito()
          .agregar(producto('a', '1'))
          .fijarCantidad('a', d('1.23456'));
      expect(carrito.cantidadDe('a'), d('1.2346'));
    });

    test('la fecha de una venta en cola usa la hora de Lima', () {
      expect(fechaEnLima(DateTime.utc(2026, 11, 10, 3)), '2026-11-09');
      expect(fechaEnLima(DateTime.utc(2026, 11, 10, 5)), '2026-11-10');
    });

    test('precio sin igv lo agrega al total', () {
      final carrito = const Carrito().agregar(producto('a', '10'));
      final sinIgv = ConfiguracionFiscal(
        igvPorcentaje: d('18'),
        preciosIncluyenIgv: false,
      );
      expect(carrito.totales(sinIgv).total, d('11.80'));
    });
  });

  group('Pagos', () {
    PagoCobro pago(MedioPago medio, String monto) =>
        PagoCobro(medio: medio, monto: d(monto));

    test('pago mixto calcula el vuelto solo sobre efectivo', () {
      final resumen = ResumenPagos([
        pago(MedioPago.yape, '20'),
        pago(MedioPago.efectivo, '50'),
      ], d('60'));
      expect(resumen.vuelto, d('10'));
      expect(resumen.cubreTotal, isTrue);
    });

    test('un exceso sin efectivo no cubre el total', () {
      final resumen = ResumenPagos([pago(MedioPago.yape, '70')], d('60'));
      expect(resumen.excesoSinEfectivo, isTrue);
      expect(resumen.cubreTotal, isFalse);
    });

    SolicitudCobro solicitud(
      TipoDocumentoVenta tipo, {
      ClientePos? cliente,
      required String total,
    }) => SolicitudCobro(
      tipo: tipo,
      carrito: const Carrito().agregar(producto('a', total)),
      pagos: [pago(MedioPago.efectivo, total)],
      cliente: cliente,
    );

    test('la factura exige RUC', () {
      expect(
        solicitud(TipoDocumentoVenta.factura, total: '10').validar(d('10')),
        contains('RUC'),
      );
    });

    test('boleta sin documento permitida hasta 700 exactos', () {
      expect(
        solicitud(TipoDocumentoVenta.boleta, total: '700').validar(d('700')),
        isNull,
      );
      expect(
        solicitud(TipoDocumentoVenta.boleta, total: '700.01').validar(d('700.01')),
        isNotNull,
      );
    });

    test('la huella cambia si cambia el contenido', () {
      final a = solicitud(TipoDocumentoVenta.boleta, total: '10');
      final b = solicitud(TipoDocumentoVenta.boleta, total: '10');
      final c = solicitud(TipoDocumentoVenta.boleta, total: '11');
      expect(a.huella(), b.huella());
      expect(a.huella(), isNot(c.huella()));
    });
  });
}
