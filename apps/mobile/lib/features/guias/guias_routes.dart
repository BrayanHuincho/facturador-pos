import 'package:facturador_pos/core/router/rutas.dart';
import 'package:go_router/go_router.dart';

import 'presentation/guia_detalle_page.dart';
import 'presentation/guia_form_page.dart';
import 'presentation/guias_page.dart';

final List<RouteBase> guiasRoutes = [
  GoRoute(
    path: Rutas.guias,
    builder: (context, state) => const GuiasPage(),
    routes: [
      GoRoute(path: 'nueva', builder: (context, state) => const GuiaFormPage()),
      GoRoute(
        path: ':id',
        builder: (context, state) =>
            GuiaDetallePage(id: state.pathParameters['id']!),
      ),
    ],
  ),
];
