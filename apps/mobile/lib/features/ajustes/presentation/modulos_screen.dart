import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errores/errores.dart';
import '../../../core/sesion/sesion_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../data/ajustes_repository.dart';

class ModulosScreen extends ConsumerStatefulWidget {
  const ModulosScreen({super.key});

  @override
  ConsumerState<ModulosScreen> createState() => _ModulosScreenState();
}

class _ModulosScreenState extends ConsumerState<ModulosScreen> {
  bool _ocupado = false;

  Future<void> _guardar(ModulosEmpresa modulos) async {
    setState(() => _ocupado = true);
    try {
      await ref.read(ajustesRepositoryProvider).guardarEmpresa({
        'modulos': modulos.toJson(),
      });
      ref.invalidate(empresaActualProvider);
      await ref.read(empresaActualProvider.future);
    } catch (error) {
      if (mounted) mostrarMensaje(context, mensajeDeError(error), error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = ref.watch(modulosEmpresaProvider);
    Widget fila(
      IconData icono,
      Color color,
      String titulo,
      String detalle,
      bool valor,
      ModulosEmpresa Function(bool) cambiar,
    ) => ListCard(
      margin: const EdgeInsets.only(bottom: AppSpace.x2),
      leading: IconChip(icono, color: color),
      title: titulo,
      subtitle: detalle,
      trailing: Switch(
        value: valor,
        onChanged: _ocupado ? null : (v) => _guardar(cambiar(v)),
      ),
    );
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(title: 'Módulos'),
          if (_ocupado) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.x4),
              children: [
                fila(
                  LucideIcons.wallet,
                  const Color(0xFF0F8A5F),
                  'Caja',
                  'Turnos, apertura y cierre',
                  m.caja,
                  (v) => m.copiar(caja: v),
                ),
                fila(
                  LucideIcons.truck,
                  const Color(0xFF0E7490),
                  'Guías de remisión',
                  'Traslado de mercadería',
                  m.guias,
                  (v) => m.copiar(guias: v),
                ),
                fila(
                  LucideIcons.chartColumn,
                  const Color(0xFF7C3AED),
                  'Reportes',
                  'Ventas e indicadores',
                  m.reportes,
                  (v) => m.copiar(reportes: v),
                ),
                fila(
                  LucideIcons.receipt,
                  const Color(0xFFC2410C),
                  'Nota de venta',
                  'Comprobante interno sin SUNAT',
                  m.notaVenta,
                  (v) => m.copiar(notaVenta: v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
