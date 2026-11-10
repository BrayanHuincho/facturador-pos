import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'almacen_sesion_segura.dart';
import 'modelos.dart';

export 'modelos.dart';

enum EstadoAcceso {
  cargando,
  error,
  sinSesion,
  sinAcceso,
  empresaPendiente,
  onboarding,
  listo,
}

final supabaseProvider = Provider<SupabaseClient>(
  (ref) => Supabase.instance.client,
);

final sesionProvider = StreamProvider<Session?>((ref) async* {
  final auth = ref.watch(supabaseProvider).auth;
  yield auth.currentSession;
  yield* auth.onAuthStateChange.map((evento) => evento.session);
});

final usuarioIdProvider = Provider<String?>(
  (ref) => ref.watch(sesionProvider).value?.user.id,
);

final perfilActualProvider = FutureProvider<Perfil?>((ref) async {
  final usuarioId = ref.watch(usuarioIdProvider);
  if (usuarioId == null) return null;
  final fila = await ref
      .watch(supabaseProvider)
      .from('perfiles')
      .select()
      .eq('id', usuarioId)
      .maybeSingle();
  return fila == null ? null : Perfil.desdeJson(fila);
});

final empresaActualProvider = FutureProvider<Empresa?>((ref) async {
  final usuarioId = ref.watch(usuarioIdProvider);
  if (usuarioId == null) return null;
  final fila = await ref
      .watch(supabaseProvider)
      .from('empresa')
      .select()
      .eq('id', 1)
      .maybeSingle();
  return fila == null ? null : Empresa.desdeJson(fila);
});

final modulosEmpresaProvider = Provider<ModulosEmpresa>(
  (ref) =>
      ref.watch(empresaActualProvider).value?.modulos ?? ModulosEmpresa.todos,
);

final rolActualProvider = Provider<RolUsuario?>(
  (ref) => ref.watch(perfilActualProvider).value?.rol,
);

class RecuperacionEnCursoNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void establecer(bool enCurso) => state = enCurso;
}

final recuperacionEnCursoProvider =
    NotifierProvider<RecuperacionEnCursoNotifier, bool>(
      RecuperacionEnCursoNotifier.new,
    );

final estadoAccesoProvider = Provider<EstadoAcceso>((ref) {
  if (ref.watch(recuperacionEnCursoProvider)) return EstadoAcceso.sinSesion;
  final sesion = ref.watch(sesionProvider);
  if (!sesion.hasValue) {
    return sesion.hasError ? EstadoAcceso.sinSesion : EstadoAcceso.cargando;
  }
  if (sesion.value == null) return EstadoAcceso.sinSesion;

  final perfilAsync = ref.watch(perfilActualProvider);
  if (!perfilAsync.hasValue) {
    return perfilAsync.hasError ? EstadoAcceso.error : EstadoAcceso.cargando;
  }
  final perfil = perfilAsync.value;
  if (perfil == null || !perfil.activo) return EstadoAcceso.sinAcceso;

  final empresaAsync = ref.watch(empresaActualProvider);
  if (!empresaAsync.hasValue) {
    return empresaAsync.hasError ? EstadoAcceso.error : EstadoAcceso.cargando;
  }
  if (empresaAsync.value?.configurada ?? false) return EstadoAcceso.listo;
  return perfil.esAdmin
      ? EstadoAcceso.onboarding
      : EstadoAcceso.empresaPendiente;
});

final controladorSesionProvider = Provider<ControladorSesion>(
  ControladorSesion.new,
);

class ControladorSesion {
  ControladorSesion(this._ref);

  final Ref _ref;

  GoTrueClient get _auth => _ref.read(supabaseProvider).auth;

  Future<void> iniciarSesion(
    String correo,
    String clave, {
    bool recordar = true,
  }) async {
    final almacen = AlmacenSesionSegura.instancia;
    await almacen.prepararInicio(recordar: recordar);
    await _auth.signInWithPassword(email: correo.trim(), password: clave);
    await almacen.registrarInicio(recordar: recordar, correo: correo.trim());
  }

  Future<void> cerrarSesion() => _auth.signOut(scope: SignOutScope.local);

  Future<void> cerrarSiVencio() async {
    if (_auth.currentSession == null) return;
    if (await AlmacenSesionSegura.instancia.sesionPasoElPlazo()) {
      await cerrarSesion();
    }
  }

  Future<void> enviarCodigoRecuperacion(String correo) =>
      _auth.resetPasswordForEmail(correo.trim());

  Future<void> restablecerClave({
    required String correo,
    required String codigo,
    required String claveNueva,
  }) async {
    final bandera = _ref.read(recuperacionEnCursoProvider.notifier);
    bandera.establecer(true);
    try {
      await _auth.verifyOTP(
        email: correo.trim(),
        token: codigo.trim(),
        type: OtpType.recovery,
      );
      try {
        await _auth.updateUser(UserAttributes(password: claveNueva));
      } finally {
        await _auth.signOut(scope: SignOutScope.local);
      }
    } finally {
      bandera.establecer(false);
    }
  }

  void reintentarCarga() {
    _ref.invalidate(perfilActualProvider);
    _ref.invalidate(empresaActualProvider);
  }
}
