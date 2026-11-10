import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/env/env.dart';
import 'core/formatos/formatos.dart';
import 'core/sesion/almacen_sesion_segura.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(localeApp);
  Intl.defaultLocale = localeApp;

  if (!Env.configurado) {
    runApp(const ConfiguracionFaltanteApp());
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: AlmacenSesionSegura.instancia,
    ),
  );
  runApp(const ProviderScope(child: FacturadorApp()));
}
