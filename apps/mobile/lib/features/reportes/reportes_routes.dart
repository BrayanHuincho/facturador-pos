import 'package:facturador_pos/core/router/rutas.dart';
import 'package:go_router/go_router.dart';

import 'presentation/reportes_page.dart';

final List<RouteBase> reportesRoutes = [
  GoRoute(
    path: Rutas.reportes,
    builder: (context, state) => const ReportesPage(),
  ),
];
