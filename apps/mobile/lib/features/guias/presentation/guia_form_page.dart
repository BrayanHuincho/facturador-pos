import 'package:decimal/decimal.dart';
import 'package:facturador_pos/core/router/rutas.dart';
import 'package:facturador_pos/features/comprobantes/domain/importes.dart';
import 'package:facturador_pos/features/comprobantes/presentation/widgets_documento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/widgets.dart' hide EstadoVacio;
import '../data/guias_repository.dart';
import '../domain/guia.dart';

final DateFormat _formatoFecha = DateFormat('yyyy-MM-dd');
final RegExp _patronUbigeo = RegExp(r'^\d{6}$');
final RegExp _patronPlaca = RegExp(r'^[A-Za-z0-9-]{6,8}$');
final RegExp _patronRuc = RegExp(r'^\d{11}$');
final RegExp _patronDni = RegExp(r'^\d{8}$');

String? _requerido(String? texto) =>
    (texto ?? '').trim().isEmpty ? 'Obligatorio' : null;

String? _validarUbigeo(String? texto) =>
    _patronUbigeo.hasMatch((texto ?? '').trim()) ? null : '6 dígitos';

String? _validarRuc(String? texto) =>
    _patronRuc.hasMatch((texto ?? '').trim()) ? null : '11 dígitos';

String? _validarDni(String? texto) =>
    _patronDni.hasMatch((texto ?? '').trim()) ? null : '8 dígitos';

String? _validarCantidad(String? texto) {
  final valor = decimalDeEntrada(texto ?? '');
  return valor == null || valor == Decimal.zero ? 'Inválido' : null;
}

class _LineaGuia {
  final descripcion = TextEditingController();
  final codigo = TextEditingController();
  final unidad = TextEditingController(text: 'NIU');
  final cantidad = TextEditingController();

  void liberar() {
    descripcion.dispose();
    codigo.dispose();
    unidad.dispose();
    cantidad.dispose();
  }
}

class GuiaFormPage extends ConsumerStatefulWidget {
  const GuiaFormPage({super.key});

  @override
  ConsumerState<GuiaFormPage> createState() => _GuiaFormPageState();
}

class _GuiaFormPageState extends ConsumerState<GuiaFormPage> {
  final _formulario = GlobalKey<FormState>();
  final _peso = TextEditingController();
  final _bultos = TextEditingController(text: '1');
  final _partidaUbigeo = TextEditingController();
  final _partidaDireccion = TextEditingController();
  final _llegadaUbigeo = TextEditingController();
  final _llegadaDireccion = TextEditingController();
  final _destinatarioNumero = TextEditingController();
  final _destinatarioNombre = TextEditingController();
  final _transportistaRuc = TextEditingController();
  final _transportistaNombre = TextEditingController();
  final _conductorDni = TextEditingController();
  final _conductorNombres = TextEditingController();
  final _conductorApellidos = TextEditingController();
  final _conductorLicencia = TextEditingController();
  final _placa = TextEditingController();
  final List<_LineaGuia> _lineas = [_LineaGuia()];

  String? _serie;
  DateTime _fechaTraslado = DateTime.now();
  String _motivo = motivosTraslado.keys.first;
  String _modalidad = modalidadesTraslado.keys.first;
  String _destinatarioTipo = tiposDocumentoDestinatario.keys.first;
  bool _enviando = false;

  bool get _esPublico => _modalidad == '01';

  @override
  void dispose() {
    for (final controlador in [
      _peso,
      _bultos,
      _partidaUbigeo,
      _partidaDireccion,
      _llegadaUbigeo,
      _llegadaDireccion,
      _destinatarioNumero,
      _destinatarioNombre,
      _transportistaRuc,
      _transportistaNombre,
      _conductorDni,
      _conductorNombres,
      _conductorApellidos,
      _conductorLicencia,
      _placa,
    ]) {
      controlador.dispose();
    }
    for (final linea in _lineas) {
      linea.liberar();
    }
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaTraslado,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 365)),
    );
    if (fecha != null) setState(() => _fechaTraslado = fecha);
  }

  Map<String, dynamic> _cuerpo() => {
    'serie': _serie,
    'fecha_traslado': _formatoFecha.format(_fechaTraslado),
    'motivo_codigo': _motivo,
    'modalidad': _modalidad,
    'peso_total': decimalDeEntrada(_peso.text).toString(),
    'unidad_peso': 'KGM',
    'bultos': int.parse(_bultos.text.trim()),
    'partida_ubigeo': _partidaUbigeo.text.trim(),
    'partida_direccion': _partidaDireccion.text.trim(),
    'llegada_ubigeo': _llegadaUbigeo.text.trim(),
    'llegada_direccion': _llegadaDireccion.text.trim(),
    'destinatario_tipo_documento': _destinatarioTipo,
    'destinatario_numero_documento': _destinatarioNumero.text.trim(),
    'destinatario_nombre': _destinatarioNombre.text.trim(),
    if (_esPublico)
      'transportista': {
        'ruc': _transportistaRuc.text.trim(),
        'razon_social': _transportistaNombre.text.trim(),
      }
    else ...{
      'conductor': {
        'tipo_documento': '1',
        'numero': _conductorDni.text.trim(),
        'nombres': _conductorNombres.text.trim(),
        'apellidos': _conductorApellidos.text.trim(),
        'licencia': _conductorLicencia.text.trim().toUpperCase(),
      },
      'vehiculo_placa': _placa.text.trim().toUpperCase(),
    },
    'items': [
      for (final linea in _lineas)
        {
          if (linea.codigo.text.trim().isNotEmpty)
            'codigo': linea.codigo.text.trim(),
          'descripcion': linea.descripcion.text.trim(),
          'unidad': linea.unidad.text.trim().toUpperCase(),
          'cantidad': decimalDeEntrada(linea.cantidad.text).toString(),
        },
    ],
  };

  Future<void> _emitir() async {
    if (_enviando || !_formulario.currentState!.validate()) return;
    setState(() => _enviando = true);
    try {
      final id = await ref.read(guiasRepositoryProvider).emitir(_cuerpo());
      if (!mounted) return;
      avisar(context, 'Guía registrada');
      context.pushReplacement('${Rutas.guias}/$id');
    } catch (error) {
      if (mounted) avisar(context, mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Widget _campo(
    TextEditingController controlador,
    String etiqueta, {
    String? Function(String?)? validador = _requerido,
    TextInputType? teclado,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.x3),
    child: CampoTexto(
      etiqueta: etiqueta,
      controller: controlador,
      teclado: teclado,
      validator: validador,
    ),
  );

  Widget _etiquetado(String etiqueta, Widget campo) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.x3),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: context.palette.text),
        ),
        const SizedBox(height: AppSpace.x1 + 2),
        campo,
      ],
    ),
  );

  Widget _seccion(String titulo, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.x3),
    child: SectionCard(
      title: titulo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _selector(
    String etiqueta,
    String valor,
    Map<String, String> opciones,
    ValueChanged<String> alCambiar,
  ) => _etiquetado(
    etiqueta,
    AppSelectorField<String>(
      titulo: etiqueta,
      icono: LucideIcons.listChecks,
      initialValue: valor,
      opciones: opciones.entries
          .map((o) => AppSelectorOption(value: o.key, label: o.value))
          .toList(),
      onChanged: (nuevo) => alCambiar(nuevo!),
    ),
  );

  String? _validarDocumentoDestinatario(String? texto) =>
      switch (_destinatarioTipo) {
        '6' => _validarRuc(texto),
        '1' => _validarDni(texto),
        _ => _requerido(texto),
      };

  @override
  Widget build(BuildContext context) {
    final series = ref.watch(seriesGuiaProvider);
    final p = context.palette;
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(title: 'Nueva guía'),
          Expanded(
            child: Form(
              key: _formulario,
              child: ListView(
                padding: const EdgeInsets.all(AppSpace.x4),
                children: [
                  _seccion('Traslado', [
                    series.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (error, _) => Text(mensajeDeError(error)),
                      data: (lista) => _etiquetado(
                        'Serie',
                        AppSelectorField<String>(
                          titulo: 'Serie',
                          icono: LucideIcons.hash,
                          initialValue: _serie,
                          opciones: lista
                              .map((s) => AppSelectorOption(value: s, label: s))
                              .toList(),
                          onChanged: (valor) => setState(() => _serie = valor),
                          validator: _requerido,
                        ),
                      ),
                    ),
                    _etiquetado(
                      'Fecha de traslado',
                      BotonSecundario(
                        texto: _formatoFecha.format(_fechaTraslado),
                        icono: LucideIcons.calendar,
                        onPressed: _elegirFecha,
                      ),
                    ),
                    _selector(
                      'Motivo',
                      _motivo,
                      motivosTraslado,
                      (v) => setState(() => _motivo = v),
                    ),
                    _selector(
                      'Modalidad',
                      _modalidad,
                      modalidadesTraslado,
                      (v) => setState(() => _modalidad = v),
                    ),
                    _campo(
                      _peso,
                      'Peso total (KGM)',
                      validador: _validarCantidad,
                      teclado: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    _campo(
                      _bultos,
                      'Bultos',
                      teclado: TextInputType.number,
                      validador: (t) =>
                          (int.tryParse((t ?? '').trim()) ?? 0) > 0
                          ? null
                          : 'Inválido',
                    ),
                  ]),
                  _seccion('Puntos', [
                    _campo(
                      _partidaUbigeo,
                      'Ubigeo de partida',
                      validador: _validarUbigeo,
                      teclado: TextInputType.number,
                    ),
                    _campo(_partidaDireccion, 'Dirección de partida'),
                    _campo(
                      _llegadaUbigeo,
                      'Ubigeo de llegada',
                      validador: _validarUbigeo,
                      teclado: TextInputType.number,
                    ),
                    _campo(_llegadaDireccion, 'Dirección de llegada'),
                  ]),
                  _seccion('Destinatario', [
                    _selector(
                      'Tipo de documento',
                      _destinatarioTipo,
                      tiposDocumentoDestinatario,
                      (v) => setState(() => _destinatarioTipo = v),
                    ),
                    _campo(
                      _destinatarioNumero,
                      'Número de documento',
                      validador: _validarDocumentoDestinatario,
                    ),
                    _campo(_destinatarioNombre, 'Nombre o razón social'),
                  ]),
                  _seccion(
                    _esPublico ? 'Transportista' : 'Conductor y vehículo',
                    _esPublico
                        ? [
                            _campo(
                              _transportistaRuc,
                              'RUC del transportista',
                              validador: _validarRuc,
                              teclado: TextInputType.number,
                            ),
                            _campo(_transportistaNombre, 'Razón social'),
                          ]
                        : [
                            _campo(
                              _conductorDni,
                              'DNI del conductor',
                              validador: _validarDni,
                              teclado: TextInputType.number,
                            ),
                            _campo(_conductorNombres, 'Nombres'),
                            _campo(_conductorApellidos, 'Apellidos'),
                            _campo(_conductorLicencia, 'Licencia'),
                            _campo(
                              _placa,
                              'Placa',
                              validador: (t) =>
                                  _patronPlaca.hasMatch((t ?? '').trim())
                                  ? null
                                  : 'Placa inválida',
                            ),
                          ],
                  ),
                  _seccion('Bienes', [
                    for (final linea in _lineas) _filaLinea(linea),
                    BotonSecundario(
                      texto: 'Agregar bien',
                      icono: LucideIcons.plus,
                      onPressed: () =>
                          setState(() => _lineas.add(_LineaGuia())),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.x4),
                child: BotonPrimario(
                  texto: _enviando ? 'Emitiendo...' : 'Emitir guía',
                  icono: LucideIcons.send,
                  onPressed: _enviando ? null : _emitir,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaLinea(_LineaGuia linea) {
    return Column(
      key: ObjectKey(linea),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _campo(linea.descripcion, 'Descripción')),
            if (_lineas.length > 1)
              IconButton(
                tooltip: 'Quitar',
                icon: const Icon(LucideIcons.x),
                onPressed: () => setState(() {
                  _lineas.remove(linea);
                  linea.liberar();
                }),
              ),
          ],
        ),
        Row(
          children: [
            Expanded(child: _campo(linea.codigo, 'Código', validador: null)),
            const SizedBox(width: AppSpace.x2),
            Expanded(child: _campo(linea.unidad, 'Unidad')),
            const SizedBox(width: AppSpace.x2),
            Expanded(
              child: _campo(
                linea.cantidad,
                'Cantidad',
                validador: _validarCantidad,
                teclado: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
        Divider(color: context.palette.border),
      ],
    );
  }
}
