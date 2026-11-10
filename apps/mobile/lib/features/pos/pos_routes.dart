import 'package:go_router/go_router.dart';

import '../../core/router/rutas.dart';
import 'presentation/cobro_screen.dart';
import 'presentation/listo_screen.dart';
import 'presentation/pos_screen.dart';
import 'presentation/vista_previa_screen.dart';

final List<RouteBase> posRoutes = [
  GoRoute(path: Rutas.pos, builder: (context, state) => const PosScreen()),
  GoRoute(
    path: Rutas.posCobro,
    builder: (context, state) => const CobroScreen(),
  ),
  GoRoute(
    path: Rutas.posVistaPrevia,
    builder: (context, state) => const VistaPreviaScreen(),
  ),
  GoRoute(
    path: Rutas.posCobroListo,
    builder: (context, state) => const ListoScreen(),
  ),
];
