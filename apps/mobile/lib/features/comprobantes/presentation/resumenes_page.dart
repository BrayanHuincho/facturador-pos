import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/widgets.dart' hide EstadoVacio;
import '../data/comprobantes_repository.dart';
import 'widgets_documento.dart';

class ResumenesPage extends StatefulWidget {
  const ResumenesPage({super.key});

  @override
  State<ResumenesPage> createState() => _ResumenesPageState();
}

class _ResumenesPageState extends State<ResumenesPage> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Resúmenes y bajas',
            bottom: AppTabs(
              onBrand: true,
              tabs: const ['Resúmenes diarios', 'Comunicaciones de baja'],
              index: _indice,
              onChanged: (valor) => setState(() => _indice = valor),
            ),
          ),
          Expanded(
            child: _indice == 0
                ? const _ListaProcesos(key: ValueKey(0), consultable: true)
                : const _ListaProcesos(key: ValueKey(1), consultable: false),
          ),
        ],
      ),
    );
  }
}

class _ListaProcesos extends ConsumerWidget {
  const _ListaProcesos({super.key, required this.consultable});

  final bool consultable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final datos = ref.watch(consultable ? resumenesProvider : bajasProvider);
    void refrescar() =>
        ref.invalidate(consultable ? resumenesProvider : bajasProvider);
    return datos.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) =>
          EstadoVacio(mensaje: mensajeDeError(error), alReintentar: refrescar),
      data: (procesos) {
        if (procesos.isEmpty) {
          return const EstadoVacio(mensaje: 'Sin registros.');
        }
        return RefreshIndicator(
          onRefresh: () async => refrescar(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.x4,
              AppSpace.x4,
              AppSpace.x4,
              AppSpace.x6,
            ),
            itemCount: procesos.length,
            itemBuilder: (context, indice) {
              final proceso = procesos[indice];
              return ListCard(
                margin: const EdgeInsets.only(bottom: AppSpace.x2 + 2),
                leading: IconChip(
                  consultable ? LucideIcons.fileStack : LucideIcons.fileX,
                ),
                title: proceso.identificador.isEmpty
                    ? proceso.fecha
                    : proceso.identificador,
                subtitleWidget: Text(
                  [
                    proceso.fecha,
                    if (proceso.ticket != null) 'Ticket ${proceso.ticket}',
                    if (proceso.sunatDescripcion != null)
                      proceso.sunatDescripcion!,
                  ].join('\n'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.palette.textMuted),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    EstadoChip(codigo: proceso.estado),
                    if (consultable && proceso.ticket != null)
                      InkWell(
                        onTap: () async {
                          try {
                            await ref
                                .read(comprobantesRepositoryProvider)
                                .consultarResumen(proceso.id);
                            if (context.mounted) {
                              avisar(context, 'Consulta enviada a SUNAT');
                            }
                            refrescar();
                          } catch (error) {
                            if (context.mounted) {
                              avisar(context, mensajeDeError(error));
                            }
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(top: AppSpace.x2),
                          child: Text(
                            'Consultar',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: context.palette.brand),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
