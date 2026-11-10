import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/reportes_repository.dart';
import '../domain/reporte.dart';

final DateFormat _formatoFecha = DateFormat('yyyy-MM-dd');

String fechaApi(DateTime fecha) => _formatoFecha.format(fecha);

DateTime _hoy() {
  final ahora = DateTime.now();
  return DateTime(ahora.year, ahora.month, ahora.day);
}

enum PeriodoReporte {
  hoy('Hoy'),
  semana('Últimos 7 días'),
  mes('Este mes'),
  treinta('Últimos 30 días'),
  rango('Rango personalizado');

  const PeriodoReporte(this.etiqueta);
  final String etiqueta;
}

class EstadoReportes {
  const EstadoReportes({
    required this.desde,
    required this.hasta,
    this.periodo = PeriodoReporte.semana,
    this.kpis,
    this.porDia = const [],
    this.porMedio = const [],
    this.porProducto = const [],
    this.cargando = false,
    this.error,
  });

  final DateTime desde;
  final DateTime hasta;
  final PeriodoReporte periodo;
  final KpisReporte? kpis;
  final List<FilaVenta> porDia;
  final List<FilaVenta> porMedio;
  final List<FilaVenta> porProducto;
  final bool cargando;
  final Object? error;

  EstadoReportes copiar({
    DateTime? desde,
    DateTime? hasta,
    PeriodoReporte? periodo,
    KpisReporte? kpis,
    List<FilaVenta>? porDia,
    List<FilaVenta>? porMedio,
    List<FilaVenta>? porProducto,
    bool? cargando,
    Object? error,
  }) => EstadoReportes(
    desde: desde ?? this.desde,
    hasta: hasta ?? this.hasta,
    periodo: periodo ?? this.periodo,
    kpis: kpis ?? this.kpis,
    porDia: porDia ?? this.porDia,
    porMedio: porMedio ?? this.porMedio,
    porProducto: porProducto ?? this.porProducto,
    cargando: cargando ?? this.cargando,
    error: error,
  );
}

final reportesProvider =
    NotifierProvider.autoDispose<ReportesController, EstadoReportes>(
      ReportesController.new,
    );

class ReportesController extends Notifier<EstadoReportes> {
  int _generacion = 0;

  @override
  EstadoReportes build() {
    final hoy = _hoy();
    Future.microtask(cargar);
    return EstadoReportes(
      desde: hoy.subtract(const Duration(days: 6)),
      hasta: hoy,
      cargando: true,
    );
  }

  Future<void> cargar() async {
    final generacion = ++_generacion;
    final consulta = state;
    state = state.copiar(cargando: true);
    final repositorio = ref.read(reportesRepositoryProvider);
    final desde = fechaApi(consulta.desde);
    final hasta = fechaApi(consulta.hasta);
    try {
      final resultados = await Future.wait<Object>([
        repositorio.resumen(desde, hasta),
        repositorio.ventas(desde, hasta, Agrupacion.dia),
        repositorio.ventas(desde, hasta, Agrupacion.medio),
        repositorio.ventas(desde, hasta, Agrupacion.producto),
      ]);
      if (!ref.mounted || generacion != _generacion) return;
      state = state.copiar(
        kpis: resultados[0] as KpisReporte,
        porDia: resultados[1] as List<FilaVenta>,
        porMedio: resultados[2] as List<FilaVenta>,
        porProducto: resultados[3] as List<FilaVenta>,
        cargando: false,
      );
    } catch (error) {
      if (!ref.mounted || generacion != _generacion) return;
      state = state.copiar(cargando: false, error: error);
    }
  }

  Future<void> elegirPeriodo(PeriodoReporte periodo) {
    final hoy = _hoy();
    return switch (periodo) {
      PeriodoReporte.hoy => _cambiar(periodo, hoy, hoy),
      PeriodoReporte.semana => _cambiar(
        periodo,
        hoy.subtract(const Duration(days: 6)),
        hoy,
      ),
      PeriodoReporte.treinta => _cambiar(
        periodo,
        hoy.subtract(const Duration(days: 29)),
        hoy,
      ),
      PeriodoReporte.mes => _cambiar(
        periodo,
        DateTime(hoy.year, hoy.month),
        hoy,
      ),
      PeriodoReporte.rango => _cambiar(periodo, state.desde, state.hasta),
    };
  }

  Future<void> elegirRango(DateTime desde, DateTime hasta) =>
      _cambiar(PeriodoReporte.rango, desde, hasta);

  Future<void> _cambiar(
    PeriodoReporte periodo,
    DateTime desde,
    DateTime hasta,
  ) async {
    state = state.copiar(periodo: periodo, desde: desde, hasta: hasta);
    await cargar();
  }

  Future<String> exportarCsv() => ref
      .read(reportesRepositoryProvider)
      .exportarCsv(fechaApi(state.desde), fechaApi(state.hasta));
}
