import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../design_system/design_system.dart';
import '../../domain/cobro.dart';
import '../cobro_controller.dart';

class ClienteSeccion extends ConsumerStatefulWidget {
  const ClienteSeccion({super.key});

  @override
  ConsumerState<ClienteSeccion> createState() => _ClienteSeccionState();
}

class _ClienteSeccionState extends ConsumerState<ClienteSeccion> {
  final _documento = TextEditingController();
  final _nombre = TextEditingController();
  final _celular = TextEditingController();

  @override
  void dispose() {
    _documento.dispose();
    _nombre.dispose();
    _celular.dispose();
    super.dispose();
  }

  void _sincronizar(TextEditingController campo, String valor) {
    if (campo.text != valor) {
      campo.value = TextEditingValue(
        text: valor,
        selection: TextSelection.collapsed(offset: valor.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(cobroControllerProvider);
    final controlador = ref.read(cobroControllerProvider.notifier);
    _sincronizar(_documento, estado.documento);
    _sincronizar(_nombre, estado.nombreManual);
    _sincronizar(_celular, estado.celular);
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final total = controlador.totalVigente;
    final factura = estado.tipo == TipoDocumentoVenta.factura;
    final encontrado =
        estado.consulta == EstadoConsulta.encontrado &&
        estado.cliente != null &&
        estado.cliente!.numeroDocumento == estado.documento;
    final pedirNombre =
        estado.documentoCompleto &&
        !encontrado &&
        (estado.consulta == EstadoConsulta.noEncontrado ||
            estado.consulta == EstadoConsulta.noConfigurada ||
            estado.consulta == EstadoConsulta.error);
    final errorCliente = estado.errorCliente(total);
    final superaTope = total > topeBoletaSinDocumento;
    final mostrarError =
        errorCliente != null &&
        (estado.documento.isEmpty
            ? superaTope || factura
            : estado.documentoCompleto || estado.documento.length > 3) &&
        estado.consulta != EstadoConsulta.buscando &&
        !pedirNombre;
    return SectionCard(
      title: 'Cliente',
      action: factura
          ? null
          : _ClientesVarios(
              elegido: estado.documento.isEmpty,
              alTocar: controlador.clientesVarios,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: factura ? 'RUC' : 'DNI (opcional)',
            controller: _documento,
            prefixIcon: LucideIcons.idCard,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(estado.digitosDocumento),
            ],
            helper: !factura && superaTope ? 'Obligatorio desde S/ 700' : null,
            errorText: mostrarError ? errorCliente : null,
            onChanged: controlador.cambiarDocumento,
          ),
          if (estado.consulta == EstadoConsulta.buscando)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.x2),
              child: Row(
                children: [
                  const SizedBox.square(
                    dimension: AppSizes.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpace.x2),
                  Flexible(
                    child: Text(
                      'Buscando en SUNAT/RENIEC…',
                      style: t.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          if (encontrado)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(estado.cliente!.nombre, style: t.titleSmall),
                        if (factura && estado.cliente!.direccion != null)
                          Text(
                            estado.cliente!.direccion!,
                            style: t.bodySmall?.copyWith(color: p.textMuted),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar cliente',
                    visualDensity: VisualDensity.compact,
                    color: p.textMuted,
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => controlador.cambiarDocumento(''),
                  ),
                ],
              ),
            ),
          if (pedirNombre) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpace.x2,
                bottom: AppSpace.x2,
              ),
              child: Text(switch (estado.consulta) {
                EstadoConsulta.noEncontrado =>
                  'No encontramos ese documento. Escribe el nombre.',
                EstadoConsulta.noConfigurada =>
                  'La consulta automática no está activa. Escribe el nombre.',
                _ => 'No pudimos consultar. Escribe el nombre.',
              }, style: t.bodySmall?.copyWith(color: p.warning)),
            ),
            AppTextField(
              label: factura ? 'Razón social' : 'Nombre completo',
              controller: _nombre,
              textInputAction: TextInputAction.done,
              onChanged: controlador.cambiarNombre,
            ),
          ],
          if (estado.sugerencias.isNotEmpty && !encontrado)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.x2),
              child: Column(
                children: [
                  for (final cliente in estado.sugerencias.take(5))
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: IconChip(
                        LucideIcons.user,
                        color: p.brand,
                        size: 36,
                      ),
                      title: Text(
                        cliente.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(cliente.numeroDocumento),
                      onTap: () => controlador.elegirCliente(cliente),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.x3),
          AppTextField(
            label: 'Celular del cliente',
            controller: _celular,
            prefixIcon: LucideIcons.phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            errorText: estado.celular.length == 9 ? estado.errorCelular : null,
            onChanged: controlador.cambiarCelular,
          ),
        ],
      ),
    );
  }
}

class _ClientesVarios extends StatelessWidget {
  const _ClientesVarios({required this.elegido, required this.alTocar});

  final bool elegido;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = elegido ? p.brand : p.textMuted;
    return InkWell(
      borderRadius: AppRadii.pillAll,
      onTap: alTocar,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 40),
        child: Center(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.x3,
              vertical: AppSpace.x1 + 2,
            ),
            decoration: BoxDecoration(
              color: elegido ? p.brandSoft : null,
              borderRadius: AppRadii.pillAll,
              border: Border.all(
                color: elegido ? p.brand.withValues(alpha: 0.35) : p.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.users, size: 14, color: color),
                const SizedBox(width: AppSpace.x1 + 2),
                Text(
                  'Clientes varios',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
