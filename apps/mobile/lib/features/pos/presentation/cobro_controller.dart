import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/formatos/validadores.dart';
import '../../../core/api/api_client.dart';
import '../../../core/sesion/sesion_providers.dart';

import '../../impresion/domain/impresora.dart';
import '../../impresion/presentation/impresion_providers.dart';
import '../domain/catalogo_pos.dart';
import '../domain/cobro.dart';
import '../domain/cola_checkout.dart';
import 'pos_providers.dart';

class ResultadoCobro {
  const ResultadoCobro({
    required this.clave,
    required this.total,
    required this.vuelto,
    this.comprobante,
    this.rechazo,
    this.cliente,
    this.avisoImpresion,
  });

  final String clave;
  final Decimal total;
  final Decimal vuelto;
  final Map<String, dynamic>? comprobante;
  final String? rechazo;
  final ClientePos? cliente;
  final String? avisoImpresion;

  bool get enCola => comprobante == null && rechazo == null;
}

enum EstadoConsulta {
  inactiva,
  buscando,
  encontrado,
  noEncontrado,
  noConfigurada,
  error,
}

const _esperaCliente = Duration(milliseconds: 300);

class EstadoCobro {
  const EstadoCobro({
    this.tipo = TipoDocumentoVenta.boleta,
    this.documento = '',
    this.cliente,
    this.nombreManual = '',
    this.celular = '',
    this.consulta = EstadoConsulta.inactiva,
    this.sugerencias = const [],
    this.pagos = const [],
    this.previsualizacion,
    this.cargandoPrevisualizacion = false,
    this.procesando = false,
    this.error,
    this.resultado,
  });

  final TipoDocumentoVenta tipo;
  final String documento;
  final ClientePos? cliente;
  final String nombreManual;
  final String celular;
  final EstadoConsulta consulta;
  final List<ClientePos> sugerencias;
  final List<PagoCobro> pagos;
  final Previsualizacion? previsualizacion;
  final bool cargandoPrevisualizacion;
  final bool procesando;
  final String? error;
  final ResultadoCobro? resultado;

  int get digitosDocumento => tipo == TipoDocumentoVenta.factura ? 11 : 8;

  bool get documentoCompleto => documento.length == digitosDocumento;

  String get nombreCliente {
    final manual = nombreManual.trim();
    if (manual.isNotEmpty) return manual;
    final actual = cliente;
    return actual != null && actual.numeroDocumento == documento
        ? actual.nombre
        : '';
  }

  ClientePos? get clienteFinal {
    if (documento.isEmpty) return null;
    final actual = cliente;
    final telefono = celularPeru(celular);
    if (actual != null && actual.numeroDocumento == documento) {
      final manual = nombreManual.trim();
      return manual.isEmpty || actual.id != null
          ? actual.copiar(telefono: telefono)
          : actual.copiar(nombre: manual, telefono: telefono);
    }
    return ClientePos(
      tipoDocumento: documento.length == 11
          ? tipoDocumentoRuc
          : tipoDocumentoDni,
      numeroDocumento: documento,
      nombre: nombreCliente,
      telefono: telefono,
    );
  }

  String? get errorCelular => errorDeCelular(celular);

  String? errorCliente(Decimal total) {
    if (tipo == TipoDocumentoVenta.factura) {
      if (documento.isEmpty) return 'La factura necesita el RUC del cliente.';
      if (documento.length != 11 ||
          !const ['10', '15', '17', '20'].contains(documento.substring(0, 2))) {
        return 'El RUC tiene 11 dígitos y empieza con 10 o 20.';
      }
      if (nombreCliente.isEmpty) return 'Falta la razón social.';
      return null;
    }
    if (documento.isEmpty) {
      return tipo == TipoDocumentoVenta.boleta && total > topeBoletaSinDocumento
          ? 'Una boleta de más de S/ 700 necesita el DNI del cliente.'
          : null;
    }
    if (documento.length != 8) return 'El DNI tiene 8 dígitos.';
    if (nombreCliente.isEmpty) return 'Falta el nombre del cliente.';
    return null;
  }

  EstadoCobro copiar({
    TipoDocumentoVenta? tipo,
    String? documento,
    ClientePos? cliente,
    bool quitarCliente = false,
    String? nombreManual,
    String? celular,
    EstadoConsulta? consulta,
    List<ClientePos>? sugerencias,
    List<PagoCobro>? pagos,
    Previsualizacion? previsualizacion,
    bool quitarPrevisualizacion = false,
    bool? cargandoPrevisualizacion,
    bool? procesando,
    String? error,
    bool quitarError = false,
    ResultadoCobro? resultado,
  }) => EstadoCobro(
    tipo: tipo ?? this.tipo,
    documento: documento ?? this.documento,
    cliente: quitarCliente ? null : cliente ?? this.cliente,
    nombreManual: nombreManual ?? this.nombreManual,
    celular: celular ?? this.celular,
    consulta: consulta ?? this.consulta,
    sugerencias: sugerencias ?? this.sugerencias,
    pagos: pagos ?? this.pagos,
    previsualizacion: quitarPrevisualizacion
        ? null
        : previsualizacion ?? this.previsualizacion,
    cargandoPrevisualizacion:
        cargandoPrevisualizacion ?? this.cargandoPrevisualizacion,
    procesando: procesando ?? this.procesando,
    error: quitarError ? null : error ?? this.error,
    resultado: resultado ?? this.resultado,
  );
}

final cobroControllerProvider = NotifierProvider<CobroController, EstadoCobro>(
  CobroController.new,
);

class CobroController extends Notifier<EstadoCobro> {
  String? _clave;
  String? _huellaClave;
  int _turnoPrevisualizacion = 0;
  bool _pagosEditados = false;
  bool _emitiendo = false;
  StreamSubscription<ResultadoEnvio>? _eventos;
  Timer? _consultaTimer;
  Timer? _busquedaTimer;

  @override
  EstadoCobro build() {
    final cola = ref.watch(colaCheckoutProvider);
    _eventos?.cancel();
    _eventos = cola?.eventos.listen(_alEventoCola);
    ref.onDispose(() {
      _eventos?.cancel();
      _cancelarBusquedas();
    });
    return const EstadoCobro();
  }

  ConfiguracionFiscal get _fiscal =>
      ref.read(catalogoProvider).value?.fiscal ??
      ConfiguracionFiscal.porDefecto();

  Decimal get _totalEstimado =>
      ref.read(carritoProvider).totales(_fiscal).total;

  Decimal get totalVigente => state.previsualizacion?.total ?? _totalEstimado;

  void _cancelarBusquedas() {
    _consultaTimer?.cancel();
    _busquedaTimer?.cancel();
  }

  void reiniciar() {
    _cancelarBusquedas();
    _clave = null;
    _huellaClave = null;
    state = const EstadoCobro();
  }

  List<MedioPago> get _mediosActivos {
    final codigos =
        ref.read(empresaActualProvider).value?.mediosPago ??
        mediosPagoPorDefecto;
    final medios = [
      for (final codigo in codigos) ?MedioPago.desdeCodigo(codigo),
    ];
    return medios.isEmpty ? [MedioPago.efectivo] : medios;
  }

  void iniciar() {
    _cancelarBusquedas();
    _clave = null;
    _huellaClave = null;
    _pagosEditados = false;
    state = EstadoCobro(
      pagos: [PagoCobro(medio: _mediosActivos.first, monto: _totalEstimado)],
    );
    unawaited(actualizarPrevisualizacion());
  }

  void elegirTipo(TipoDocumentoVenta tipo) {
    if (tipo == state.tipo) return;
    final cambiaDigitos =
        (tipo == TipoDocumentoVenta.factura) !=
        (state.tipo == TipoDocumentoVenta.factura);
    state = state.copiar(tipo: tipo, quitarError: true);
    if (cambiaDigitos) cambiarDocumento('', forzar: true);
    unawaited(actualizarPrevisualizacion());
  }

  void cambiarDocumento(String texto, {bool forzar = false}) {
    var documento = texto.replaceAll(RegExp(r'\D'), '');
    if (documento.length > state.digitosDocumento) {
      documento = documento.substring(0, state.digitosDocumento);
    }
    if (documento == state.documento && !forzar) return;
    _cancelarBusquedas();
    final sigue =
        state.cliente != null && state.cliente!.numeroDocumento == documento;
    state = state.copiar(
      documento: documento,
      quitarCliente: !sigue,
      nombreManual: sigue ? state.nombreManual : '',
      consulta: sigue ? state.consulta : EstadoConsulta.inactiva,
      sugerencias: documento.length >= 3 && !sigue
          ? state.sugerencias
          : const [],
      quitarError: true,
    );
    if (sigue) return;
    if (state.documentoCompleto) {
      _consultaTimer = Timer(
        _esperaCliente,
        () => unawaited(consultarDocumento(documento)),
      );
    }
    if (documento.length >= 3) {
      _busquedaTimer = Timer(
        _esperaCliente,
        () => unawaited(buscarClientes(documento)),
      );
    }
  }

  Future<void> consultarDocumento(String documento) async {
    if (documento != state.documento) return;
    state = state.copiar(consulta: EstadoConsulta.buscando);
    final tipo = documento.length == 11 ? tipoDocumentoRuc : tipoDocumentoDni;
    try {
      final cliente = await ref
          .read(posApiProvider)
          .consultarDocumento(tipo, documento);
      if (!ref.mounted || documento != state.documento) return;
      if (cliente == null) {
        if (state.cliente?.id != null) return;
        state = state.copiar(consulta: EstadoConsulta.noEncontrado);
        return;
      }
      final guardado = state.cliente?.id != null;
      state = state.copiar(
        cliente: guardado ? state.cliente : cliente,
        consulta: EstadoConsulta.encontrado,
      );
      unawaited(actualizarPrevisualizacion());
    } on ApiException catch (error) {
      if (!ref.mounted || documento != state.documento) return;
      if (state.cliente?.id != null) return;
      state = state.copiar(
        consulta: error.codigo == 'CONSULTA_NO_CONFIGURADA'
            ? EstadoConsulta.noConfigurada
            : EstadoConsulta.error,
      );
    } catch (_) {
      if (!ref.mounted || documento != state.documento) return;
      if (state.cliente?.id != null) return;
      state = state.copiar(consulta: EstadoConsulta.error);
    }
  }

  Future<void> buscarClientes(String consulta) async {
    if (consulta != state.documento) return;
    try {
      final lista = await ref
          .read(catalogoRepositoryProvider)
          .buscarClientes(consulta);
      if (!ref.mounted || consulta != state.documento) return;
      final exacto = lista
          .where((c) => c.numeroDocumento == consulta && c.id != null)
          .firstOrNull;
      if (exacto != null && state.documentoCompleto) {
        state = state.copiar(
          cliente: exacto,
          sugerencias: const [],
          consulta: EstadoConsulta.encontrado,
          celular: state.celular.isEmpty
              ? celularPeru(exacto.telefono) ?? ''
              : state.celular,
        );
        unawaited(actualizarPrevisualizacion());
      } else {
        state = state.copiar(sugerencias: lista);
      }
    } catch (_) {
      return;
    }
  }

  void elegirCliente(ClientePos cliente) {
    _cancelarBusquedas();
    final esRuc = cliente.numeroDocumento.length == 11;
    state = state.copiar(
      tipo: esRuc ? TipoDocumentoVenta.factura : state.tipo,
      documento: cliente.numeroDocumento,
      cliente: cliente,
      nombreManual: '',
      celular: state.celular.isEmpty
          ? celularPeru(cliente.telefono) ?? ''
          : state.celular,
      sugerencias: const [],
      consulta: EstadoConsulta.encontrado,
      quitarError: true,
    );
    unawaited(actualizarPrevisualizacion());
  }

  void clientesVarios() {
    _cancelarBusquedas();
    state = state.copiar(
      documento: '',
      quitarCliente: true,
      nombreManual: '',
      sugerencias: const [],
      consulta: EstadoConsulta.inactiva,
      quitarError: true,
    );
    unawaited(actualizarPrevisualizacion());
  }

  void cambiarNombre(String nombre) {
    state = state.copiar(nombreManual: nombre, quitarError: true);
  }

  void cambiarCelular(String texto) {
    var digitos = texto.replaceAll(RegExp(r'\D'), '');
    if (digitos.length > 9) digitos = digitos.substring(0, 9);
    state = state.copiar(celular: digitos);
  }

  MedioPago get _medioAdicional => _mediosActivos.firstWhere(
    (m) => m != MedioPago.efectivo,
    orElse: () => _mediosActivos.first,
  );

  void agregarPago() {
    _pagosEditados = true;
    final resumen = ResumenPagos(state.pagos, totalVigente);
    state = state.copiar(
      pagos: [
        ...state.pagos,
        PagoCobro(medio: _medioAdicional, monto: resumen.faltante),
      ],
      quitarError: true,
    );
  }

  void actualizarPago(int indice, PagoCobro pago) {
    _pagosEditados = true;
    final copia = [...state.pagos];
    copia[indice] = pago;
    state = state.copiar(pagos: copia, quitarError: true);
  }

  void quitarPago(int indice) {
    _pagosEditados = true;
    final copia = [...state.pagos]..removeAt(indice);
    state = state.copiar(pagos: copia, quitarError: true);
  }

  SolicitudCobro _solicitud(List<PagoCobro> pagos, {String? fechaEmision}) =>
      SolicitudCobro(
        tipo: state.tipo,
        carrito: ref.read(carritoProvider),
        pagos: pagos,
        cliente: state.clienteFinal,
        fechaEmision: fechaEmision,
      );

  SolicitudCobro get solicitudActual => _solicitud(state.pagos);

  String? bloqueo(Decimal total) {
    final cliente = state.errorCliente(total);
    if (cliente != null) return cliente;
    final celular = state.errorCelular;
    if (celular != null && state.celular.length == 9) return celular;
    return solicitudActual.validar(total);
  }

  Future<void> actualizarPrevisualizacion() async {
    final carrito = ref.read(carritoProvider);
    if (carrito.vacio) return;
    final turno = ++_turnoPrevisualizacion;
    if (state.errorCliente(_totalEstimado) != null) {
      final vista = Previsualizacion.estimadaDe(
        carrito.totales(_fiscal),
        estimada: false,
      );
      state = state.copiar(
        previsualizacion: vista,
        cargandoPrevisualizacion: false,
        pagos: _pagosAjustados(vista.total),
      );
      return;
    }
    state = state.copiar(cargandoPrevisualizacion: true);
    final holgura = _totalEstimado * Decimal.fromInt(2) + Decimal.ten;
    final cuerpo = _solicitud([
      PagoCobro(medio: MedioPago.efectivo, monto: holgura),
    ]).cuerpo();
    try {
      final vista = await ref.read(posApiProvider).previsualizar(cuerpo);
      if (turno != _turnoPrevisualizacion) return;
      state = state.copiar(
        previsualizacion: vista,
        cargandoPrevisualizacion: false,
        pagos: _pagosAjustados(vista.total),
        quitarError: true,
      );
    } on FalloDefinitivo catch (e) {
      if (turno != _turnoPrevisualizacion) return;
      state = state.copiar(
        quitarPrevisualizacion: true,
        cargandoPrevisualizacion: false,
        error: e.mensaje,
      );
    } on FalloTransitorio {
      if (turno != _turnoPrevisualizacion) return;
      final vista = Previsualizacion.estimadaDe(carrito.totales(_fiscal));
      state = state.copiar(
        previsualizacion: vista,
        cargandoPrevisualizacion: false,
        pagos: _pagosAjustados(vista.total),
      );
    } catch (_) {
      if (turno != _turnoPrevisualizacion) return;
      state = state.copiar(
        quitarPrevisualizacion: true,
        cargandoPrevisualizacion: false,
        error: 'No se pudo calcular el total. Inténtalo de nuevo.',
      );
    }
  }

  List<PagoCobro> _pagosAjustados(Decimal total) {
    if (_pagosEditados || state.pagos.length != 1) return state.pagos;
    return [PagoCobro(medio: state.pagos.first.medio, monto: total)];
  }

  String _claveDe(String huella) {
    if (_clave != null && _huellaClave == huella) return _clave!;
    _huellaClave = huella;
    return _clave = const Uuid().v4();
  }

  Future<void> cobrar() async {
    if (_emitiendo || state.resultado != null) return;
    final vista = state.previsualizacion;
    final cola = ref.read(colaCheckoutProvider);
    if (vista == null || cola == null || state.cargandoPrevisualizacion) return;
    final solicitud = _solicitud(
      state.pagos,
      fechaEmision: vista.estimada ? fechaEnLima(DateTime.now()) : null,
    );
    final invalido = solicitud.validar(vista.total);
    if (invalido != null) {
      state = state.copiar(error: invalido);
      return;
    }
    _emitiendo = true;
    state = state.copiar(procesando: true, quitarError: true);
    final clave = _claveDe(solicitud.huella());
    final resumen = ResumenPagos(solicitud.pagos, vista.total);
    try {
      await cola.encolar(clave, solicitud.cuerpo());
      final envio = await cola.enviar(clave);
      switch (envio) {
        case EnvioExitoso(:final comprobante):
          _clave = null;
          _huellaClave = null;
          ref.read(carritoProvider.notifier).limpiar();
          state = state.copiar(
            procesando: false,
            resultado: ResultadoCobro(
              clave: clave,
              total: vista.total,
              vuelto: resumen.vuelto,
              comprobante: comprobante,
              cliente: solicitud.clienteEfectivo,
            ),
          );
          unawaited(_imprimirSiCorresponde(comprobante));
        case EnvioEnEspera():
          _clave = null;
          _huellaClave = null;
          ref.read(carritoProvider.notifier).limpiar();
          state = state.copiar(
            procesando: false,
            resultado: ResultadoCobro(
              clave: clave,
              total: vista.total,
              vuelto: resumen.vuelto,
              cliente: solicitud.clienteEfectivo,
            ),
          );
        case EnvioRechazado(:final motivo):
          await cola.descartar(clave);
          state = state.copiar(procesando: false, error: motivo);
      }
    } catch (_) {
      state = state.copiar(
        procesando: false,
        error: 'No se pudo guardar la venta en este dispositivo.',
      );
    } finally {
      _emitiendo = false;
    }
  }

  void _alEventoCola(ResultadoEnvio evento) {
    final actual = state.resultado;
    if (actual == null || !actual.enCola || actual.clave != evento.clave) {
      return;
    }
    switch (evento) {
      case EnvioExitoso(:final comprobante):
        state = state.copiar(
          resultado: ResultadoCobro(
            clave: actual.clave,
            total: actual.total,
            vuelto: actual.vuelto,
            comprobante: comprobante,
            cliente: actual.cliente,
          ),
        );
        unawaited(_imprimirSiCorresponde(comprobante));
      case EnvioRechazado(:final motivo):
        state = state.copiar(
          resultado: ResultadoCobro(
            clave: actual.clave,
            total: actual.total,
            vuelto: actual.vuelto,
            rechazo: motivo,
            cliente: actual.cliente,
          ),
        );
      case EnvioEnEspera():
        break;
    }
  }

  Future<void> _imprimirSiCorresponde(Map<String, dynamic> comprobante) async {
    try {
      final config = await ref.read(configImpresoraProvider.future);
      if (!config.imprimirAlEmitir || !config.configurada) return;
      await ref
          .read(impresionServiceProvider)
          .imprimirComprobante(
            comprobante: comprobante,
            empresa: await ref.read(empresaTicketProvider.future),
          );
    } on FalloImpresora catch (e) {
      final actual = state.resultado;
      if (actual == null) return;
      state = state.copiar(
        resultado: ResultadoCobro(
          clave: actual.clave,
          total: actual.total,
          vuelto: actual.vuelto,
          comprobante: actual.comprobante,
          rechazo: actual.rechazo,
          cliente: actual.cliente,
          avisoImpresion: e.mensaje,
        ),
      );
    } catch (_) {
      return;
    }
  }
}
