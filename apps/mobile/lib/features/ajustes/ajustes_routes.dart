import 'package:go_router/go_router.dart';

import '../../core/router/rutas.dart';
import '../impresion/impresora_routes.dart';
import 'presentation/ajustes_screen.dart';
import 'presentation/empresa_screen.dart';
import 'presentation/pasar_produccion_screen.dart';
import 'presentation/medios_pago_screen.dart';
import 'presentation/perfil_screen.dart';
import 'presentation/modulos_screen.dart';
import 'presentation/series_screen.dart';
import 'presentation/sunat_screen.dart';
import 'presentation/usuarios_screen.dart';

final List<RouteBase> ajustesRoutes = [
  GoRoute(path: Rutas.ajustes, builder: (_, _) => const AjustesScreen()),
  GoRoute(path: Rutas.ajustesPerfil, builder: (_, _) => const PerfilScreen()),
  GoRoute(path: Rutas.ajustesSunat, builder: (_, _) => const SunatScreen()),
  GoRoute(
    path: Rutas.ajustesProduccion,
    builder: (_, _) => const PasarProduccionScreen(),
  ),
  GoRoute(
    path: Rutas.ajustesMediosPago,
    builder: (_, _) => const MediosPagoScreen(),
  ),
  GoRoute(path: Rutas.ajustesModulos, builder: (_, _) => const ModulosScreen()),
  GoRoute(path: Rutas.ajustesEmpresa, builder: (_, _) => const EmpresaScreen()),
  GoRoute(path: Rutas.ajustesSeries, builder: (_, _) => const SeriesScreen()),
  GoRoute(
    path: Rutas.ajustesUsuarios,
    builder: (_, _) => const UsuariosScreen(),
  ),
  ...impresoraRoutes,
];
