import 'package:flutter/widgets.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'raiz');
final shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

class Rutas {
  const Rutas._();

  static const cargando = '/cargando';
  static const login = '/login';
  static const recuperarClave = '/recuperar-clave';
  static const sinAcceso = '/sin-acceso';
  static const onboarding = '/onboarding';
  static const pos = '/pos';
  static const posCobro = '/pos/cobro';
  static const posVistaPrevia = '/pos/cobro/vista-previa';
  static const posCobroListo = '/pos/cobro/listo';
  static const comprobantes = '/comprobantes';
  static const comprobanteDetalle = '/comprobantes/:id';
  static const caja = '/caja';
  static const productos = '/productos';
  static const productoDetalle = '/productos/:id';
  static const clientes = '/clientes';
  static const guias = '/guias';
  static const reportes = '/reportes';
  static const ajustes = '/ajustes';
  static const ajustesPerfil = '/ajustes/perfil';
  static const ajustesSunat = '/ajustes/sunat';
  static const ajustesProduccion = '/ajustes/sunat/produccion';
  static const ajustesMediosPago = '/ajustes/medios-pago';
  static const ajustesModulos = '/ajustes/modulos';
  static const ajustesEmpresa = '/ajustes/empresa';
  static const ajustesSeries = '/ajustes/series';
  static const ajustesUsuarios = '/ajustes/usuarios';
  static const ajustesImpresora = '/ajustes/impresora';

  static String comprobante(String id) => '$comprobantes/$id';
  static String producto(String id) => '$productos/$id';
}
