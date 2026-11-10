import 'package:facturador_pos/core/router/rutas.dart';
import 'package:go_router/go_router.dart';

import 'presentation/caja_page.dart';

final List<RouteBase> cajaRoutes = [
  GoRoute(path: Rutas.caja, builder: (context, state) => const CajaPage()),
];
