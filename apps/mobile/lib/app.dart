import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'core/router/router.dart';
import 'core/sesion/sesion_providers.dart';
import 'core/tema/tema.dart';
import 'core/widgets/widgets.dart';

const _nombreApp = 'Facturador POS';
const _localesSoportados = [Locale('es', 'PE'), Locale('es')];
const _delegadosLocalizacion = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

class FacturadorApp extends ConsumerStatefulWidget {
  const FacturadorApp({super.key});

  @override
  ConsumerState<FacturadorApp> createState() => _FacturadorAppState();
}

class _FacturadorAppState extends ConsumerState<FacturadorApp> {
  late final AppLifecycleListener _ciclo;

  @override
  void initState() {
    super.initState();
    _ciclo = AppLifecycleListener(
      onResume: () => ref.read(controladorSesionProvider).cerrarSiVencio(),
    );
  }

  @override
  void dispose() {
    _ciclo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: _nombreApp,
      debugShowCheckedModeBanner: false,
      theme: temaClaro,
      darkTheme: temaOscuro,
      locale: const Locale('es', 'PE'),
      supportedLocales: _localesSoportados,
      localizationsDelegates: _delegadosLocalizacion,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class ConfiguracionFaltanteApp extends StatelessWidget {
  const ConfiguracionFaltanteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _nombreApp,
      debugShowCheckedModeBanner: false,
      theme: temaClaro,
      darkTheme: temaOscuro,
      locale: const Locale('es', 'PE'),
      supportedLocales: _localesSoportados,
      localizationsDelegates: _delegadosLocalizacion,
      home: const Scaffold(
        body: EstadoVacio(
          icono: LucideIcons.settings,
          titulo: 'Falta configurar la aplicación',
          mensaje:
              'Compila con --dart-define-from-file=env.json e incluye '
              'SUPABASE_URL, SUPABASE_ANON_KEY y API_URL.',
        ),
      ),
    );
  }
}
