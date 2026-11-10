import '../sesion/sesion_providers.dart';
import 'rutas.dart';

const _rutasPublicas = {Rutas.login, Rutas.recuperarClave};
const _rutasDeEntrada = {
  Rutas.login,
  Rutas.recuperarClave,
  Rutas.cargando,
  Rutas.sinAcceso,
};
const _rutasSoloAdmin = [
  Rutas.ajustesSunat,
  Rutas.ajustesEmpresa,
  Rutas.ajustesSeries,
  Rutas.ajustesUsuarios,
  Rutas.ajustesMediosPago,
  Rutas.ajustesModulos,
];
const _rutasDeVenta = [Rutas.pos, Rutas.caja];

String inicioPorRol(RolUsuario? rol) =>
    rol == RolUsuario.contador ? Rutas.comprobantes : Rutas.pos;

bool _coincide(String ubicacion, String ruta) =>
    ubicacion == ruta || ubicacion.startsWith('$ruta/');

bool rutaPermitida(
  RolUsuario? rol,
  String ubicacion, {
  ModulosEmpresa modulos = ModulosEmpresa.todos,
}) {
  if (!modulos.caja && _coincide(ubicacion, Rutas.caja)) return false;
  if (!modulos.guias && _coincide(ubicacion, Rutas.guias)) return false;
  if (!modulos.reportes && _coincide(ubicacion, Rutas.reportes)) return false;
  if (_rutasSoloAdmin.any((r) => _coincide(ubicacion, r))) {
    return rol == RolUsuario.admin;
  }
  if (_rutasDeVenta.any((r) => _coincide(ubicacion, r))) {
    return rol != RolUsuario.contador;
  }
  if (_coincide(ubicacion, Rutas.reportes)) return rol != RolUsuario.cajero;
  return true;
}

String? _ir(String ubicacion, String destino) =>
    ubicacion == destino ? null : destino;

String? destinoRedirigido({
  required EstadoAcceso estado,
  required RolUsuario? rol,
  required String ubicacion,
  ModulosEmpresa modulos = ModulosEmpresa.todos,
}) {
  switch (estado) {
    case EstadoAcceso.cargando:
    case EstadoAcceso.error:
      return _ir(ubicacion, Rutas.cargando);
    case EstadoAcceso.sinSesion:
      return _rutasPublicas.contains(ubicacion) ? null : Rutas.login;
    case EstadoAcceso.sinAcceso:
    case EstadoAcceso.empresaPendiente:
      return _ir(ubicacion, Rutas.sinAcceso);
    case EstadoAcceso.onboarding:
      return _ir(ubicacion, Rutas.onboarding);
    case EstadoAcceso.listo:
      if (_rutasDeEntrada.contains(ubicacion)) return inicioPorRol(rol);
      if (ubicacion == Rutas.onboarding) {
        return rol == RolUsuario.admin ? null : inicioPorRol(rol);
      }
      return rutaPermitida(rol, ubicacion, modulos: modulos)
          ? null
          : inicioPorRol(rol);
  }
}
