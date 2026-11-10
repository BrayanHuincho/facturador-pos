import 'package:facturador_pos/core/router/rutas.dart';
import 'package:facturador_pos/features/comprobantes/domain/comprobante.dart';
import 'package:facturador_pos/features/comprobantes/presentation/widgets_documento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../design_system/design_system.dart';
import '../domain/guia.dart';
import 'guias_controller.dart';

const _estadosFiltro = [
  EstadoDocumento.pendiente,
  EstadoDocumento.enviando,
  EstadoDocumento.procesando,
  EstadoDocumento.aceptado,
  EstadoDocumento.observado,
  EstadoDocumento.rechazado,
  EstadoDocumento.error,
];

class GuiasPage extends ConsumerStatefulWidget {
  const GuiasPage({super.key});

  @override
  ConsumerState<GuiasPage> createState() => _GuiasPageState();
}

class _GuiasPageState extends ConsumerState<GuiasPage> {
  final _desplazamiento = ScrollController();

  @override
  void initState() {
    super.initState();
    _desplazamiento.addListener(() {
      if (_desplazamiento.position.extentAfter < 400) {
        ref.read(listadoGuiasProvider.notifier).cargarMas();
      }
    });
  }

  @override
  void dispose() {
    _desplazamiento.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listado = ref.watch(listadoGuiasProvider);
    final controlador = ref.read(listadoGuiasProvider.notifier);
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Guías de remisión',
            actions: [
              AppHeaderAction(
                icon: LucideIcons.plus,
                tooltip: 'Nueva guía',
                label: 'Nueva',
                onPressed: () => context.push('${Rutas.guias}/nueva'),
              ),
            ],
          ),
          ColoredBox(
            color: context.palette.surface,
            child: AppTabs(
              expand: false,
              tabs: [
                'Todas',
                for (final estado in _estadosFiltro) estado.etiqueta,
              ],
              index:
                  _estadosFiltro.indexWhere((e) => e.codigo == listado.estado) +
                  1,
              onChanged: (i) => controlador.filtrar(
                i == 0 ? null : _estadosFiltro[i - 1].codigo,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: controlador.recargar,
              child: _contenido(listado),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenido(ListadoGuias listado) {
    if (listado.items.isEmpty) {
      if (listado.cargando) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          EstadoVacio(
            mensaje: listado.error != null
                ? mensajeDeError(listado.error!)
                : 'No hay guías para este filtro.',
          ),
        ],
      );
    }
    return ListView.builder(
      controller: _desplazamiento,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.x4,
        AppSpace.x2,
        AppSpace.x4,
        AppSpace.x6,
      ),
      itemCount: listado.items.length,
      itemBuilder: (context, indice) {
        final Guia guia = listado.items[indice];
        return ListCard(
          margin: const EdgeInsets.only(bottom: AppSpace.x2 + 2),
          onTap: () => context.push('${Rutas.guias}/${guia.id}'),
          leading: const IconChip(LucideIcons.truck),
          title: guia.numero,
          subtitle:
              '${guia.destinatarioNombre} · Traslado ${guia.fechaTraslado}',
          trailing: EstadoChip(codigo: guia.estado),
        );
      },
    );
  }
}
