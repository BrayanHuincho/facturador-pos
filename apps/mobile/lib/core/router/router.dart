import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/ajustes/ajustes_routes.dart';
import '../../features/auth/presentation/acceso_pages.dart';
import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/recuperar_clave_page.dart';
import '../../features/caja/caja_routes.dart';
import '../../features/catalogo/catalogo_routes.dart';
import '../../features/comprobantes/comprobantes_routes.dart';
import '../../features/guias/guias_routes.dart';
import '../../features/onboarding/presentation/onboarding_page.dart';
import '../../features/pos/pos_routes.dart';
import '../../features/reportes/reportes_routes.dart';
import '../../features/shell/shell_principal.dart';
import '../sesion/sesion_providers.dart';
import 'redireccion.dart';
import 'rutas.dart';

export 'rutas.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresco = ValueNotifier<int>(0);
  ref.onDispose(refresco.dispose);
  ref.listen(estadoAccesoProvider, (_, _) => refresco.value++);
  ref.listen(rolActualProvider, (_, _) => refresco.value++);
  ref.listen(modulosEmpresaProvider, (_, _) => refresco.value++);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Rutas.cargando,
    refreshListenable: refresco,
    redirect: (BuildContext _, GoRouterState estado) => destinoRedirigido(
      estado: ref.read(estadoAccesoProvider),
      rol: ref.read(rolActualProvider),
      ubicacion: estado.matchedLocation,
      modulos: ref.read(modulosEmpresaProvider),
    ),
    routes: [
      GoRoute(path: Rutas.cargando, builder: (_, _) => const CargandoPage()),
      GoRoute(path: Rutas.login, builder: (_, _) => const LoginPage()),
      GoRoute(
        path: Rutas.recuperarClave,
        builder: (_, _) => const RecuperarClavePage(),
      ),
      GoRoute(path: Rutas.sinAcceso, builder: (_, _) => const SinAccesoPage()),
      GoRoute(
        path: Rutas.onboarding,
        builder: (_, _) => const OnboardingPage(),
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (_, estado, child) =>
            ShellPrincipal(ubicacion: estado.uri.path, child: child),
        routes: [
          ...posRoutes,
          ...comprobantesRoutes,
          ...cajaRoutes,
          ...reportesRoutes,
          ...catalogoRoutes,
          ...ajustesRoutes,
          ...guiasRoutes,
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
