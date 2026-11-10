import 'package:facturador_pos/core/router/rutas.dart';
import 'package:go_router/go_router.dart';

import 'presentation/comprobante_detalle_page.dart';
import 'presentation/comprobantes_page.dart';
import 'presentation/nota_page.dart';
import 'presentation/resumenes_page.dart';

final List<RouteBase> comprobantesRoutes = [
  GoRoute(
    path: Rutas.comprobantes,
    builder: (context, state) => const ComprobantesPage(),
    routes: [
      GoRoute(
        path: 'resumenes',
        builder: (context, state) => const ResumenesPage(),
      ),
      GoRoute(
        path: ':id',
        builder: (context, state) =>
            ComprobanteDetallePage(id: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'nota',
            builder: (context, state) => NotaPage(
              id: state.pathParameters['id']!,
              tipo: state.uri.queryParameters['tipo'] == '08' ? '08' : '07',
            ),
          ),
        ],
      ),
    ],
  ),
];
