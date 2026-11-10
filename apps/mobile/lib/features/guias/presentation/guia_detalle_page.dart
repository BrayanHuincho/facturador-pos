import 'package:facturador_pos/features/comprobantes/domain/importes.dart';
import 'package:facturador_pos/features/comprobantes/presentation/widgets_documento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../comprobantes/data/archivos_compartidos.dart';
import '../../../core/widgets/widgets.dart' hide EstadoVacio;
import '../data/guias_repository.dart';
import '../domain/guia.dart';

class GuiaDetallePage extends ConsumerStatefulWidget {
  const GuiaDetallePage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<GuiaDetallePage> createState() => _GuiaDetallePageState();
}

class _GuiaDetallePageState extends ConsumerState<GuiaDetallePage> {
  bool _reenviando = false;
  bool _compartiendo = false;

  Future<void> _compartir(Guia guia, String tipo, String extension) async {
    setState(() => _compartiendo = true);
    try {
      final url = await ref
          .read(guiasRepositoryProvider)
          .urlArchivo(guia.id, tipo);
      await compartirDesdeUrl(
        url: url,
        nombre: '${guia.numero}-$tipo.$extension',
        titulo: 'Guía ${guia.numero}',
      );
    } catch (error) {
      if (mounted) avisar(context, mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _compartiendo = false);
    }
  }

  Future<void> _reenviar() async {
    if (_reenviando) return;
    setState(() => _reenviando = true);
    try {
      await ref.read(guiasRepositoryProvider).reenviar(widget.id);
      if (mounted) avisar(context, 'Reenvío en cola');
    } catch (error) {
      if (mounted) avisar(context, mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detalle = ref.watch(guiaDetalleProvider(widget.id));
    return Scaffold(
      body: Column(
        children: [
          AppHeader(title: detalle.value?.numero ?? 'Guía'),
          Expanded(
            child: detalle.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => EstadoVacio(
                mensaje: mensajeDeError(error),
                alReintentar: () =>
                    ref.invalidate(guiaDetalleProvider(widget.id)),
              ),
              data: _cuerpo,
            ),
          ),
        ],
      ),
    );
  }

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

  Widget _cuerpo(Guia guia) {
    return ListView(
      padding: const EdgeInsets.all(AppSpace.x4),
      children: [
        _seccion('Guía de remisión', [
          Row(
            children: [
              const IconChip(LucideIcons.truck),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: Text(
                  guia.numero,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              EstadoChip(codigo: guia.estado),
            ],
          ),
          const SizedBox(height: AppSpace.x2),
          FilaDato('Destinatario', guia.destinatarioNombre),
          FilaDato('Documento', guia.destinatarioNumeroDocumento),
          FilaDato('Emisión', guia.fechaEmision),
          FilaDato('Traslado', guia.fechaTraslado),
          FilaDato(
            'Motivo',
            motivosTraslado[guia.motivoCodigo] ?? guia.motivoCodigo,
          ),
          FilaDato(
            'Modalidad',
            modalidadesTraslado[guia.modalidad] ?? guia.modalidad,
          ),
          FilaDato(
            'Peso',
            '${formatearCantidad(guia.pesoTotal)} ${guia.unidadPeso}',
          ),
          FilaDato('Partida', guia.partidaDireccion),
          FilaDato('Llegada', guia.llegadaDireccion),
          if (guia.vehiculoPlaca != null)
            FilaDato('Placa', guia.vehiculoPlaca!),
        ]),
        _seccion('Bienes', [
          for (final item in guia.items)
            FilaDato(
              item.descripcion,
              '${formatearCantidad(item.cantidad)} ${item.unidad}',
            ),
        ]),
        _seccion('Respuesta SUNAT', [
          FilaDato('Código', guia.sunatCodigo ?? 'Sin respuesta'),
          if (guia.ticket != null) FilaDato('Ticket', guia.ticket!),
          if (guia.sunatDescripcion != null) Text(guia.sunatDescripcion!),
        ]),
        if (guia.tieneArchivos)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.x3),
            child: Row(
              children: [
                for (final (indice, (tipo, extension)) in const [
                  ('pdf', 'pdf'),
                  ('xml', 'xml'),
                  ('cdr', 'zip'),
                ].indexed) ...[
                  if (indice > 0) const SizedBox(width: AppSpace.x2),
                  Expanded(
                    child: BotonSecundario(
                      texto: tipo.toUpperCase(),
                      icono: LucideIcons.share,
                      onPressed: _compartiendo
                          ? null
                          : () => _compartir(guia, tipo, extension),
                    ),
                  ),
                ],
              ],
            ),
          ),
        if (guia.puedeReenviar)
          BotonPrimario(
            texto: 'Reenviar',
            icono: LucideIcons.send,
            onPressed: _reenviando ? null : _reenviar,
          ),
      ],
    );
  }
}
