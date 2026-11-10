import 'package:decimal/decimal.dart';
import 'package:facturador_pos/core/api/api_client.dart';
import 'package:facturador_pos/core/sesion/sesion_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/caja.dart';

final cajaRepositoryProvider = Provider<CajaRepository>(
  (ref) =>
      CajaRepository(ref.watch(supabaseProvider), ref.watch(apiClientProvider)),
);

final turnoActualProvider = FutureProvider.autoDispose<TurnoConResumen?>(
  (ref) => ref.watch(cajaRepositoryProvider).turnoActual(),
);

final movimientosTurnoProvider = FutureProvider.autoDispose
    .family<List<MovimientoCaja>, String>(
      (ref, turnoId) => ref.watch(cajaRepositoryProvider).movimientos(turnoId),
    );

final turnosCerradosProvider = FutureProvider.autoDispose<List<Turno>>(
  (ref) => ref.watch(cajaRepositoryProvider).turnosCerrados(),
);

final resumenTurnoProvider = FutureProvider.autoDispose
    .family<TurnoConResumen, String>(
      (ref, turnoId) => ref.watch(cajaRepositoryProvider).resumen(turnoId),
    );

class CajaRepository {
  CajaRepository(this._cliente, this._api);

  final SupabaseClient _cliente;
  final ApiClient _api;

  Future<TurnoConResumen?> turnoActual() async {
    final json = await _api.get<Map<String, dynamic>>('/caja/turno-actual');
    return json['turno'] == null ? null : TurnoConResumen.desdeJson(json);
  }

  Future<void> abrir(Decimal montoApertura) => _api.post<dynamic>(
    '/caja/abrir',
    data: {'monto_apertura': montoApertura.toString()},
  );

  Future<TurnoConResumen> cerrar(
    Decimal montoContado,
    String? observacion,
  ) async {
    final json = await _api.post<Map<String, dynamic>>(
      '/caja/cerrar',
      data: {
        'monto_contado': montoContado.toString(),
        if (observacion != null && observacion.isNotEmpty)
          'observacion': observacion,
      },
    );
    return TurnoConResumen.desdeJson(json);
  }

  Future<void> registrarMovimiento({
    required String tipo,
    required Decimal monto,
    required String concepto,
  }) => _api.post<dynamic>(
    '/caja/movimientos',
    data: {'tipo': tipo, 'monto': monto.toString(), 'concepto': concepto},
  );

  Future<TurnoConResumen> resumen(String turnoId) async {
    final json = await _api.get<Map<String, dynamic>>(
      '/caja/turnos/$turnoId/resumen',
    );
    return TurnoConResumen.desdeJson(json);
  }

  Future<List<MovimientoCaja>> movimientos(String turnoId) async {
    final filas = await _cliente
        .from('movimientos_caja')
        .select()
        .eq('turno_id', turnoId)
        .order('creado_en');
    return filas.map(MovimientoCaja.desdeFila).toList();
  }

  Future<List<Turno>> turnosCerrados() async {
    final usuarioId = _cliente.auth.currentUser?.id;
    if (usuarioId == null) return const [];
    final filas = await _cliente
        .from('turnos_caja')
        .select()
        .eq('estado', 'cerrado')
        .eq('usuario_id', usuarioId)
        .order('cerrado_en')
        .limit(20);
    return filas.map(Turno.desdeFila).toList();
  }
}
