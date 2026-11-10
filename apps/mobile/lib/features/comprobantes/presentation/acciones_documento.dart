import 'package:facturador_pos/core/formatos/validadores.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../design_system/design_system.dart';
import '../../impresion/domain/impresora.dart';
import '../../impresion/presentation/impresion_providers.dart';
import '../../pos/presentation/pos_providers.dart';
import '../../pos/presentation/widgets/medio_pago_logo.dart';
import '../data/archivos_compartidos.dart';
import '../data/comprobantes_repository.dart';
import 'documento_comprobante.dart';

Future<void> compartirComprobantePdf(
  WidgetRef ref, {
  required String id,
  required String numero,
  Rect? origen,
}) async {
  final formato = await formatoPdfPredeterminado(ref);
  final url = await ref
      .read(comprobantesRepositoryProvider)
      .urlArchivo(id, formato);
  await compartirDesdeUrl(
    url: url,
    nombre: '$numero.pdf',
    titulo: numero,
    origen: origen,
  );
}

Future<void> enviarComprobantePorWhatsapp(
  WidgetRef ref, {
  required String id,
  required String numero,
  required String celular,
}) async {
  final formato = await formatoPdfPredeterminado(ref);
  final url = await ref
      .read(comprobantesRepositoryProvider)
      .urlArchivo(id, formato);
  final texto = Uri.encodeComponent('Tu comprobante $numero: $url');
  final abierto = await launchUrl(
    Uri.parse('https://wa.me/51$celular?text=$texto'),
    mode: LaunchMode.externalApplication,
  );
  if (!abierto) throw const FalloImpresora('No se pudo abrir WhatsApp.');
}

Future<void> imprimirComprobante(
  WidgetRef ref, {
  required Map<String, dynamic> comprobante,
}) async {
  await ref
      .read(impresionServiceProvider)
      .imprimirComprobante(
        comprobante: comprobante,
        empresa: await ref.read(empresaTicketProvider.future),
      );
}

Future<void> ejecutarConAviso(
  BuildContext context,
  Future<void> Function() accion,
) async {
  final toaster = AppToast.para(context);
  try {
    await accion();
  } on FalloImpresora catch (error) {
    toaster.error(error.mensaje);
  } catch (_) {
    toaster.error('No se pudo completar la acción.');
  }
}

class BotonImprimirCabecera extends StatefulWidget {
  const BotonImprimirCabecera({required this.alImprimir, super.key});

  final Future<void> Function()? alImprimir;

  @override
  State<BotonImprimirCabecera> createState() => _BotonImprimirCabeceraState();
}

class _BotonImprimirCabeceraState extends State<BotonImprimirCabecera> {
  bool _ocupado = false;

  Future<void> _tocar() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    await ejecutarConAviso(context, widget.alImprimir!);
    if (mounted) setState(() => _ocupado = false);
  }

  @override
  Widget build(BuildContext context) => AppHeaderAction(
    icon: LucideIcons.printer,
    tooltip: 'Imprimir',
    onPressed: widget.alImprimir == null || _ocupado ? null : _tocar,
  );
}

class BotonWhatsappCabecera extends StatefulWidget {
  const BotonWhatsappCabecera({
    required this.alEnviar,
    this.celular,
    super.key,
  });

  final Future<void> Function(String celular)? alEnviar;
  final String? celular;

  @override
  State<BotonWhatsappCabecera> createState() => _BotonWhatsappCabeceraState();
}

class _BotonWhatsappCabeceraState extends State<BotonWhatsappCabecera> {
  bool _enviando = false;
  String? _ultimo;

  Future<void> _tocar() async {
    if (_enviando) return;
    final elegido = await AppBottomSheet.show<String>(
      context,
      title: 'Enviar por WhatsApp',
      child: _CelularSheet(
        inicial: celularPeru(_ultimo ?? widget.celular) ?? '',
      ),
    );
    if (elegido == null || !mounted) return;
    _ultimo = elegido;
    setState(() => _enviando = true);
    await ejecutarConAviso(context, () => widget.alEnviar!(elegido));
    if (mounted) setState(() => _enviando = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final activo = widget.alEnviar != null && !_enviando;
    return Tooltip(
      message: 'Enviar por WhatsApp',
      child: TextButton.icon(
        onPressed: activo ? _tocar : null,
        style: TextButton.styleFrom(
          foregroundColor: p.onHeader,
          disabledForegroundColor: p.onHeader.withValues(alpha: 0.7),
          backgroundColor: p.onHeader.withValues(alpha: 0.14),
          disabledBackgroundColor: p.onHeader.withValues(alpha: 0.08),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.mdAll),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.x2 + 2),
          minimumSize: const Size(0, 40),
        ),
        icon: _enviando
            ? SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: p.onHeader,
                ),
              )
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: p.plate,
                  shape: BoxShape.circle,
                ),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: WhatsAppLogo(size: 20),
                ),
              ),
        label: const Text(
          'Enviar',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _CelularSheet extends StatefulWidget {
  const _CelularSheet({required this.inicial});

  final String inicial;

  @override
  State<_CelularSheet> createState() => _CelularSheetState();
}

class _CelularSheetState extends State<_CelularSheet> {
  late final _celular = TextEditingController(text: widget.inicial);
  String? _error;

  @override
  void dispose() {
    _celular.dispose();
    super.dispose();
  }

  void _enviar() {
    final texto = _celular.text.trim();
    final error = errorDeCelular(texto);
    if (error != null || texto.isEmpty) {
      setState(() => _error = error ?? 'Escribe el celular.');
      return;
    }
    Navigator.of(context).pop(texto);
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AppTextField(
        label: 'Celular',
        controller: _celular,
        hint: '987 654 321',
        errorText: _error,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(9),
        ],
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _enviar(),
      ),
      const SizedBox(height: AppSpace.x4),
      AppButton(
        label: 'Enviar',
        icon: LucideIcons.send,
        size: AppButtonSize.large,
        expand: true,
        onPressed: _enviar,
      ),
    ],
  );
}
