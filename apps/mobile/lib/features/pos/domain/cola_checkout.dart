import 'dart:async';
import 'dart:convert';

enum EstadoEntradaCola { pendiente, rechazada }

class EntradaCola {
  const EntradaCola({
    required this.clave,
    required this.cuerpo,
    required this.creadoEn,
    this.estado = EstadoEntradaCola.pendiente,
    this.intentos = 0,
    this.ultimoError,
  });

  factory EntradaCola.fromJson(Map<String, dynamic> json) => EntradaCola(
    clave: json['clave'] as String,
    cuerpo: Map<String, dynamic>.from(json['cuerpo'] as Map),
    creadoEn: DateTime.parse(json['creado_en'] as String),
    estado:
        EstadoEntradaCola.values.asNameMap()[json['estado']] ??
        EstadoEntradaCola.pendiente,
    intentos: json['intentos'] as int? ?? 0,
    ultimoError: json['ultimo_error'] as String?,
  );

  final String clave;
  final Map<String, dynamic> cuerpo;
  final DateTime creadoEn;
  final EstadoEntradaCola estado;
  final int intentos;
  final String? ultimoError;

  EntradaCola copiar({
    EstadoEntradaCola? estado,
    int? intentos,
    String? ultimoError,
  }) => EntradaCola(
    clave: clave,
    cuerpo: cuerpo,
    creadoEn: creadoEn,
    estado: estado ?? this.estado,
    intentos: intentos ?? this.intentos,
    ultimoError: ultimoError ?? this.ultimoError,
  );

  Map<String, dynamic> toJson() => {
    'clave': clave,
    'cuerpo': cuerpo,
    'creado_en': creadoEn.toIso8601String(),
    'estado': estado.name,
    'intentos': intentos,
    'ultimo_error': ultimoError,
  };
}

abstract interface class AlmacenCola {
  Future<String?> leer();
  Future<void> escribir(String contenido);
}

abstract interface class EmisorCheckout {
  Future<Map<String, dynamic>> emitir(
    String claveIdempotencia,
    Map<String, dynamic> cuerpo,
  );
}

class FalloTransitorio implements Exception {
  const FalloTransitorio(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

class FalloDefinitivo implements Exception {
  const FalloDefinitivo(this.mensaje, {this.codigo});
  final String mensaje;
  final String? codigo;

  @override
  String toString() => mensaje;
}

sealed class ResultadoEnvio {
  const ResultadoEnvio(this.clave);
  final String clave;
}

class EnvioExitoso extends ResultadoEnvio {
  const EnvioExitoso(super.clave, this.comprobante);
  final Map<String, dynamic> comprobante;
}

class EnvioEnEspera extends ResultadoEnvio {
  const EnvioEnEspera(super.clave, this.motivo);
  final String motivo;
}

class EnvioRechazado extends ResultadoEnvio {
  const EnvioRechazado(super.clave, this.motivo);
  final String motivo;
}

class ColaCheckout {
  ColaCheckout({required this._almacen, required this._emisor});

  final AlmacenCola _almacen;
  final EmisorCheckout _emisor;
  final List<EntradaCola> _entradas = [];
  final Map<String, Future<ResultadoEnvio>> _enCurso = {};
  final StreamController<ResultadoEnvio> _eventos =
      StreamController<ResultadoEnvio>.broadcast();
  final StreamController<List<EntradaCola>> _cambios =
      StreamController<List<EntradaCola>>.broadcast();

  Future<void>? _carga;
  Future<void> _escritura = Future.value();
  Future<void>? _vaciado;

  Stream<ResultadoEnvio> get eventos => _eventos.stream;
  Stream<List<EntradaCola>> get cambios => _cambios.stream;
  List<EntradaCola> get entradas => List.unmodifiable(_entradas);

  Future<void> cargar() => _carga ??= _cargarDesdeAlmacen();

  Future<void> _cargarDesdeAlmacen() async {
    final contenido = await _almacen.leer();
    if (contenido != null && contenido.isNotEmpty) {
      final lista = jsonDecode(contenido) as List<dynamic>;
      _entradas.addAll(
        lista.map(
          (e) => EntradaCola.fromJson(Map<String, dynamic>.from(e as Map)),
        ),
      );
    }
    _notificar();
  }

  Future<void> encolar(String clave, Map<String, dynamic> cuerpo) async {
    await cargar();
    if (_entradas.any((e) => e.clave == clave)) return;
    _entradas.add(
      EntradaCola(clave: clave, cuerpo: cuerpo, creadoEn: DateTime.now()),
    );
    await _persistir();
  }

  Future<ResultadoEnvio> enviar(String clave) async {
    await cargar();
    return _enCurso[clave] ??= _enviarUna(clave).whenComplete(() {
      _enCurso.remove(clave);
    });
  }

  Future<ResultadoEnvio> _enviarUna(String clave) async {
    final indice = _indice(clave);
    if (indice < 0) {
      return EnvioRechazado(clave, 'La venta ya no está en la cola.');
    }
    final entrada = _entradas[indice];
    final ResultadoEnvio resultado;
    try {
      final comprobante = await _emisor.emitir(clave, entrada.cuerpo);
      _entradas.removeWhere((e) => e.clave == clave);
      resultado = EnvioExitoso(clave, comprobante);
    } on FalloDefinitivo catch (e) {
      _reemplazar(
        clave,
        (actual) => actual.copiar(
          estado: EstadoEntradaCola.rechazada,
          intentos: actual.intentos + 1,
          ultimoError: e.mensaje,
        ),
      );
      await _persistir();
      final rechazo = EnvioRechazado(clave, e.mensaje);
      _emitirEvento(rechazo);
      return rechazo;
    } on FalloTransitorio catch (e) {
      _reemplazar(
        clave,
        (actual) => actual.copiar(
          intentos: actual.intentos + 1,
          ultimoError: e.mensaje,
        ),
      );
      await _persistir();
      return EnvioEnEspera(clave, e.mensaje);
    } catch (_) {
      const motivo = 'Ocurrió un error inesperado. Revisa en Comprobantes.';
      _reemplazar(
        clave,
        (actual) => actual.copiar(
          estado: EstadoEntradaCola.rechazada,
          intentos: actual.intentos + 1,
          ultimoError: motivo,
        ),
      );
      await _persistir();
      final rechazo = EnvioRechazado(clave, motivo);
      _emitirEvento(rechazo);
      return rechazo;
    }
    await _persistir();
    _emitirEvento(resultado);
    return resultado;
  }

  Future<void> vaciar() =>
      _vaciado ??= _vaciarPendientes().whenComplete(() => _vaciado = null);

  Future<void> _vaciarPendientes() async {
    await cargar();
    final claves = [
      for (final e in _entradas)
        if (e.estado == EstadoEntradaCola.pendiente) e.clave,
    ];
    for (final clave in claves) {
      final resultado = await enviar(clave);
      if (resultado is EnvioEnEspera) return;
    }
  }

  Future<void> reintentar(String clave) async {
    await cargar();
    _reemplazar(
      clave,
      (actual) => actual.copiar(estado: EstadoEntradaCola.pendiente),
    );
    await _persistir();
    await enviar(clave);
  }

  Future<void> descartar(String clave) async {
    await cargar();
    _entradas.removeWhere((e) => e.clave == clave);
    await _persistir();
  }

  Future<void> cerrar() async {
    await _eventos.close();
    await _cambios.close();
  }

  int _indice(String clave) => _entradas.indexWhere((e) => e.clave == clave);

  void _reemplazar(String clave, EntradaCola Function(EntradaCola) cambio) {
    final indice = _indice(clave);
    if (indice >= 0) _entradas[indice] = cambio(_entradas[indice]);
  }

  void _emitirEvento(ResultadoEnvio evento) {
    if (!_eventos.isClosed) _eventos.add(evento);
  }

  void _notificar() {
    if (!_cambios.isClosed) _cambios.add(entradas);
  }

  Future<void> _persistir() {
    final contenido = jsonEncode(_entradas.map((e) => e.toJson()).toList());
    _notificar();
    return _escritura = _escritura.then((_) => _almacen.escribir(contenido));
  }
}
