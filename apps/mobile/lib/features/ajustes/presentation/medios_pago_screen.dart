import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errores/errores.dart';
import '../../../core/sesion/sesion_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../../pos/domain/cobro.dart';
import '../../pos/presentation/widgets/medio_pago_logo.dart';
import '../../pos/presentation/widgets/qr_grande.dart';
import '../data/ajustes_repository.dart';

const _mediosConfigurables = [
  MedioPago.efectivo,
  MedioPago.yape,
  MedioPago.plin,
  MedioPago.transferencia,
  MedioPago.tarjeta,
  MedioPago.deposito,
];

class MediosPagoScreen extends ConsumerStatefulWidget {
  const MediosPagoScreen({super.key});

  @override
  ConsumerState<MediosPagoScreen> createState() => _MediosPagoScreenState();
}

class _MediosPagoScreenState extends ConsumerState<MediosPagoScreen> {
  bool _ocupado = false;

  Future<void> _guardar(Map<String, dynamic> cambios, String exito) async {
    setState(() => _ocupado = true);
    try {
      await ref.read(ajustesRepositoryProvider).guardarEmpresa(cambios);
      ref.invalidate(empresaActualProvider);
      await ref.read(empresaActualProvider.future);
      if (mounted) mostrarMensaje(context, exito);
    } catch (error) {
      if (mounted) mostrarMensaje(context, mensajeDeError(error), error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _alternar(Empresa empresa, MedioPago medio, bool activo) async {
    final nuevos = [
      for (final m in _mediosConfigurables)
        if (m == medio ? activo : empresa.mediosPago.contains(m.name)) m.name,
    ];
    if (nuevos.isEmpty) {
      mostrarMensaje(context, 'Deja al menos un medio activo.', error: true);
      return;
    }
    await _guardar({'medios_pago': nuevos}, '${medio.etiqueta} actualizado');
  }

  Future<void> _subirQr(MedioPago medio) async {
    final XFile? imagen;
    try {
      imagen = await ImagePicker().pickImage(source: ImageSource.gallery);
    } on PlatformException {
      if (mounted) {
        mostrarMensaje(context, 'No se pudo abrir la imagen.', error: true);
      }
      return;
    }
    if (imagen == null || !mounted) return;
    setState(() => _ocupado = true);
    try {
      final ruta = await ref
          .read(ajustesRepositoryProvider)
          .subirLogo(
            contenido: await imagen.readAsBytes(),
            nombreArchivo: imagen.name,
          );
      await _guardar({
        'qr_${medio.name}_path': ruta,
      }, 'QR de ${medio.etiqueta} guardado');
    } catch (error) {
      if (mounted) {
        mostrarMensaje(context, mensajeDeError(error), error: true);
        setState(() => _ocupado = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final empresa = ref.watch(empresaActualProvider).value;
    final repositorio = ref.read(ajustesRepositoryProvider);
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(title: 'Medios de pago'),
          if (_ocupado) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: empresa == null
                ? const EstadoCargando()
                : ListView(
                    padding: const EdgeInsets.all(AppSpace.x4),
                    children: [
                      for (final medio in _mediosConfigurables)
                        _TarjetaMedio(
                          medio: medio,
                          activo: empresa.mediosPago.contains(medio.name),
                          ocupado: _ocupado,
                          urlQr: () {
                            final ruta = switch (medio) {
                              MedioPago.yape => empresa.qrYapePath,
                              MedioPago.plin => empresa.qrPlinPath,
                              _ => null,
                            };
                            return ruta == null
                                ? null
                                : repositorio.urlPublicaImagen(ruta);
                          }(),
                          alCambiar: (valor) =>
                              _alternar(empresa, medio, valor),
                          alSubir: () => _subirQr(medio),
                          alQuitar: () => _guardar({
                            'qr_${medio.name}_path': null,
                          }, 'QR de ${medio.etiqueta} quitado'),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaMedio extends StatelessWidget {
  const _TarjetaMedio({
    required this.medio,
    required this.activo,
    required this.ocupado,
    required this.urlQr,
    required this.alCambiar,
    required this.alSubir,
    required this.alQuitar,
  });

  final MedioPago medio;
  final bool activo;
  final bool ocupado;
  final String? urlQr;
  final ValueChanged<bool> alCambiar;
  final VoidCallback alSubir;
  final VoidCallback alQuitar;

  bool get _admiteQr => medio == MedioPago.yape || medio == MedioPago.plin;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final url = urlQr;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x3),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpace.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                MedioPagoLogo(medio),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: Text(
                    medio.etiqueta,
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Switch(value: activo, onChanged: ocupado ? null : alCambiar),
              ],
            ),
            if (_admiteQr) ...[
              const SizedBox(height: AppSpace.x2),
              Row(
                children: [
                  if (url != null) ...[
                    InkWell(
                      onTap: () =>
                          mostrarQrGrande(context, medio: medio, url: url),
                      child: Container(
                        width: 64,
                        height: 64,
                        padding: const EdgeInsets.all(AppSpace.x1),
                        decoration: BoxDecoration(
                          color: p.plate,
                          borderRadius: AppRadii.mdAll,
                          border: Border.all(color: p.border),
                        ),
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Icon(LucideIcons.qrCode),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpace.x3),
                  ],
                  Expanded(
                    child: Wrap(
                      spacing: AppSpace.x2,
                      runSpacing: AppSpace.x1,
                      children: [
                        AppButton(
                          label: url == null ? 'Subir QR' : 'Cambiar',
                          icon: url == null ? LucideIcons.upload : null,
                          variant: AppButtonVariant.secondary,
                          onPressed: ocupado ? null : alSubir,
                        ),
                        if (url != null)
                          AppButton(
                            label: 'Quitar',
                            variant: AppButtonVariant.secondary,
                            onPressed: ocupado ? null : alQuitar,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
