import 'package:go_router/go_router.dart';

import '../../core/router/rutas.dart';
import 'presentation/impresora_screen.dart';

final List<RouteBase> impresoraRoutes = [
  GoRoute(
    path: Rutas.ajustesImpresora,
    builder: (context, state) => const ImpresoraScreen(),
  ),
];
