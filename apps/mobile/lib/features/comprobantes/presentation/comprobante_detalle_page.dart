import 'package:facturador_pos/core/router/rutas.dart';
import 'package:facturador_pos/core/sesion/sesion_providers.dart';
import 'package:facturador_pos/design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../data/archivos_compartidos.dart';
import '../data/comprobantes_repository.dart';
import '../domain/comprobante.dart';
import 'acciones_documento.dart';
import 'documento_comprobante.dart';
import 'widgets_documento.dart';

class _FormatoArchivo {
  const _FormatoArchivo(this.tipo, this.etiqueta, this.extension, this.icono);

  final String tipo;
  final String etiqueta;
  final String extension;
  final IconData icono;
}

const _formatosPdf = [
  _FormatoArchivo('pdf-a4', 'PDF A4', 'pdf', LucideIcons.fileText),
  _FormatoArchivo('pdf-ticket80', 'Ticket 80 mm', 'pdf', LucideIcons.receipt),
  _FormatoArchivo('pdf-ticket58', 'Ticket 58 mm', 'pdf', LucideIcons.receipt),
];
const _formatoXml = _FormatoArchivo('xml', 'XML', 'xml', LucideIcons.code);
const _formatoCdr = _FormatoArchivo(
  'cdr',
  'CDR',
  'zip',
  LucideIcons.badgeCheck,
);

class ComprobanteDetallePage extends ConsumerStatefulWidget {
  const ComprobanteDetallePage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<ComprobanteDetallePage> createState() =>
      _ComprobanteDetallePageState();
}

class _ComprobanteDetallePageState
    extends ConsumerState<ComprobanteDetallePage> {
  bool _ocupado = false;

  ComprobantesRepository get _repositorio =>
      ref.read(comprobantesRepositoryProvider);

  Future<void> _ejecutar(
    Future<void> Function() accion,
    String mensajeExito,
  ) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await accion();
      if (mounted) {
        avisar(context, mensajeExito);
        ref.invalidate(comprobanteDetalleProvider(widget.id));
      }
    } catch (error) {
      if (mounted) avisar(context, mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _anular(Comprobante comprobante) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoAnulacion(comprobante: comprobante),
    );
    if (motivo == null) return;
    await _ejecutar(
      () => _repositorio.anular(comprobante.id, motivo),
      'Anulación solicitada',
    );
  }

  Future<void> _compartir(
    Comprobante comprobante,
    _FormatoArchivo formato,
    Rect? origen,
  ) => _ejecutar(() async {
    final url = await _repositorio.urlArchivo(comprobante.id, formato.tipo);
    final base = comprobante.numero.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '');
    await compartirDesdeUrl(
      url: url,
      nombre: '$base-${formato.tipo}.${formato.extension}',
      titulo: '${comprobante.tipoEtiqueta} ${comprobante.numero}',
      origen: origen,
    );
  }, 'Archivo listo');

  Future<void> _mostrarMas(Comprobante c, bool esAdmin) =>
      AppBottomSheet.show<void>(
        context,
        title: 'Más acciones',
        child: _accionesMas(c, esAdmin),
      );

  @override
  Widget build(BuildContext context) {
    final detalle = ref.watch(comprobanteDetalleProvider(widget.id));
    final esAdmin = ref.watch(perfilActualProvider).value?.esAdmin ?? false;
    final comprobante = detalle.value;
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          AppHeader(
            title: comprobante?.numero ?? 'Comprobante',
            subtitle: comprobante == null
                ? null
                : '${comprobante.tipoEtiqueta} · ${comprobante.fechaEmision} · '
                      '${comprobante.estado.etiqueta}',
            actions: [
              if (comprobante != null) ...[
                BotonImprimirCabecera(
                  alImprimir: () async {
                    final completo = await _repositorio.obtenerMapa(
                      comprobante.id,
                    );
                    await imprimirComprobante(ref, comprobante: completo);
                  },
                ),
                BotonWhatsappCabecera(
                  alEnviar: (celular) => enviarComprobantePorWhatsapp(
                    ref,
                    id: comprobante.id,
                    numero: comprobante.numero,
                    celular: celular,
                  ),
                ),
                AppHeaderAction(
                  icon: LucideIcons.ellipsisVertical,
                  tooltip: 'Más acciones',
                  onPressed: () => _mostrarMas(comprobante, esAdmin),
                ),
              ],
            ],
          ),
          if (_ocupado) const LinearProgressIndicator(minHeight: 2),
          if (comprobante != null &&
              (comprobante.estado == EstadoDocumento.rechazado ||
                  comprobante.estado == EstadoDocumento.error))
            ColoredBox(
              color: p.dangerSoft,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.x4,
                  vertical: AppSpace.x2,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.circleAlert,
                      size: AppSizes.iconSm,
                      color: p.danger,
                    ),
                    const SizedBox(width: AppSpace.x2),
                    Expanded(
                      child: Text(
                        comprobante.sunatDescripcion ??
                            'SUNAT marcó este comprobante como '
                                '${comprobante.estado.etiqueta.toLowerCase()}.',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: p.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: detalle.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EstadoVacio(
                mensaje: mensajeDeError(error),
                alReintentar: () =>
                    ref.invalidate(comprobanteDetalleProvider(widget.id)),
              ),
              data: (c) =>
                  DocumentoComprobante(comprobanteId: c.id, refresco: c.estado),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accionesMas(Comprobante c, bool esAdmin) {
    final formatos = [
      ..._formatosPdf,
      if (c.xmlPath != null) _formatoXml,
      if (c.cdrPath != null) _formatoCdr,
    ];
    Widget opcion(IconData icono, String texto, VoidCallback alTocar) =>
        Builder(
          builder: (contexto) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(icono, size: AppSizes.iconMd),
            title: Text(texto),
            onTap: () {
              Navigator.of(contexto).pop();
              alTocar();
            },
          ),
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final formato in formatos)
          Builder(
            builder: (contexto) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(formato.icono, size: AppSizes.iconMd),
              title: Text('Compartir ${formato.etiqueta}'),
              onTap: () {
                final origen = origenCompartir(contexto);
                Navigator.of(contexto).pop();
                _compartir(c, formato, origen);
              },
            ),
          ),
        if (c.puedeReenviar)
          opcion(
            LucideIcons.send,
            'Reenviar',
            () =>
                _ejecutar(() => _repositorio.reenviar(c.id), 'Reenvío en cola'),
          ),
        if (c.puedeConsultar)
          opcion(
            LucideIcons.globe,
            'Consultar en SUNAT',
            () => _ejecutar(
              () => _repositorio.consultar(c.id),
              'Consulta enviada a SUNAT',
            ),
          ),
        if (c.admiteNotas) ...[
          opcion(
            LucideIcons.circleMinus,
            'Nota de crédito',
            () => context.push('${Rutas.comprobante(c.id)}/nota?tipo=07'),
          ),
          opcion(
            LucideIcons.circlePlus,
            'Nota de débito',
            () => context.push('${Rutas.comprobante(c.id)}/nota?tipo=08'),
          ),
        ],
        if (esAdmin && c.puedeAnular)
          opcion(LucideIcons.ban, 'Anular', () => _anular(c)),
        if (esAdmin && c.requiereNotaParaAnular)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Pasó el plazo de 7 días: para revertirlo emite una nota de crédito.',
            ),
          ),
      ],
    );
  }
}

class _DialogoAnulacion extends StatefulWidget {
  const _DialogoAnulacion({required this.comprobante});

  final Comprobante comprobante;

  @override
  State<_DialogoAnulacion> createState() => _DialogoAnulacionState();
}

class _DialogoAnulacionState extends State<_DialogoAnulacion> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comprobante;
    return AppDialog(
      title: Text('Anular ${c.numero}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            c.esNotaDeVenta
                ? 'La nota de venta se anula localmente y repone el stock.'
                : 'Se comunicará la baja a SUNAT. Esta acción no se puede deshacer.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _motivo,
            autofocus: true,
            maxLength: 100,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Motivo'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _motivo.text.trim().length < 3
              ? null
              : () => Navigator.pop(context, _motivo.text.trim()),
          child: const Text('Anular'),
        ),
      ],
    );
  }
}
