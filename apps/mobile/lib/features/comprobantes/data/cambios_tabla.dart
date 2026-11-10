import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class CambioFila {
  const CambioFila(this.evento, this.fila);

  const CambioFila.sincronizar() : evento = null, fila = const {};

  final PostgresChangeEvent? evento;
  final Map<String, dynamic> fila;

  bool get esSincronizacion => evento == null;
}

int _secuenciaCanal = 0;

Stream<CambioFila> observarTabla(
  SupabaseClient cliente,
  String tabla, {
  String? id,
}) {
  late final StreamController<CambioFila> salida;
  RealtimeChannel? canal;
  salida = StreamController<CambioFila>(
    onListen: () {
      canal = cliente
          .channel('$tabla-${_secuenciaCanal++}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: tabla,
            filter: id == null
                ? null
                : PostgresChangeFilter(
                    type: PostgresChangeFilterType.eq,
                    column: 'id',
                    value: id,
                  ),
            callback: (cambio) {
              if (!salida.isClosed) {
                salida.add(CambioFila(cambio.eventType, cambio.newRecord));
              }
            },
          )
          .subscribe((estado, _) {
            if (estado == RealtimeSubscribeStatus.subscribed &&
                !salida.isClosed) {
              salida.add(const CambioFila.sincronizar());
            }
          });
    },
    onCancel: () async {
      final abierto = canal;
      if (abierto != null) await cliente.removeChannel(abierto);
    },
  );
  return salida.stream;
}
