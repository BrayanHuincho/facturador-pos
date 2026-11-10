import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/router/rutas.dart';
import '../../../core/sesion/sesion_providers.dart';
import '../../../core/widgets/widgets.dart';
import 'banner_modo_prueba.dart';

const _sepItem = SizedBox(height: AppSpace.x2);

class AjustesScreen extends ConsumerWidget {
  const AjustesScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context, WidgetRef ref) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AppDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('Tendrás que volver a ingresar con tu correo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    try {
      await ref.read(controladorSesionProvider).cerrarSesion();
    } catch (error) {
      if (context.mounted) {
        mostrarMensaje(context, 'No se pudo cerrar la sesión.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilActualProvider).value;
    final empresa = ref.watch(empresaActualProvider).value;
    final esAdmin = perfil?.esAdmin ?? false;
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Ajustes',
            automaticBack: false,
            bottom: perfil == null
                ? null
                : Row(
                    children: [
                      AvatarIniciales(
                        nombre: perfil.nombre,
                        fotoUrl: perfil.fotoUrl,
                      ),
                      const SizedBox(width: AppSpace.x3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              perfil.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.titleMedium?.copyWith(color: p.onHeader),
                            ),
                            Text(
                              [
                                perfil.rol.etiqueta,
                                ?empresa?.nombreVisible,
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodySmall?.copyWith(
                                color: p.onHeader.withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          if (esAdmin) const BannerModoPrueba(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.x4),
              children: [
                const _Opcion(
                  icono: LucideIcons.circleUser,
                  color: Color(0xFF1F5BD8),
                  titulo: 'Mi perfil',
                  detalle: 'Tu nombre y foto',
                  ruta: Rutas.ajustesPerfil,
                ),
                _sepItem,
                if (esAdmin) ...[
                  const _Opcion(
                    icono: LucideIcons.shieldCheck,
                    titulo: 'SUNAT',
                    detalle: 'Credenciales, certificado y entorno',
                    ruta: Rutas.ajustesSunat,
                  ),
                  _sepItem,
                  const _Opcion(
                    icono: LucideIcons.creditCard,
                    color: Color(0xFF0F8A5F),
                    titulo: 'Medios de pago',
                    detalle: 'Métodos visibles y QR de Yape y Plin',
                    ruta: Rutas.ajustesMediosPago,
                  ),
                  _sepItem,
                  const _Opcion(
                    icono: LucideIcons.layoutGrid,
                    color: Color(0xFFBE185D),
                    titulo: 'Módulos',
                    detalle: 'Caja, guías, reportes y nota de venta',
                    ruta: Rutas.ajustesModulos,
                  ),
                  _sepItem,
                  const _Opcion(
                    icono: LucideIcons.store,
                    color: Color(0xFF0E7490),
                    titulo: 'Empresa',
                    detalle: 'Datos, logo y plantilla de comprobantes',
                    ruta: Rutas.ajustesEmpresa,
                  ),
                  _sepItem,
                  const _Opcion(
                    icono: LucideIcons.hash,
                    color: Color(0xFFC2410C),
                    titulo: 'Series',
                    detalle: 'Numeración de comprobantes',
                    ruta: Rutas.ajustesSeries,
                  ),
                  _sepItem,
                  const _Opcion(
                    icono: LucideIcons.users,
                    color: Color(0xFF7C3AED),
                    titulo: 'Usuarios',
                    detalle: 'Accesos y roles',
                    ruta: Rutas.ajustesUsuarios,
                  ),
                  _sepItem,
                ],
                const _Opcion(
                  icono: LucideIcons.printer,
                  color: Color(0xFF0F8A5F),
                  titulo: 'Impresora',
                  detalle: 'Ticketera y formato de impresión',
                  ruta: Rutas.ajustesImpresora,
                ),
                const SizedBox(height: AppSpace.x5),
                AppButton(
                  label: 'Cerrar sesión',
                  icon: LucideIcons.logOut,
                  variant: AppButtonVariant.secondary,
                  expand: true,
                  onPressed: () => _cerrarSesion(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  const _Opcion({
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.ruta,
    this.color,
  });

  final IconData icono;
  final Color? color;
  final String titulo;
  final String detalle;
  final String ruta;

  @override
  Widget build(BuildContext context) => ListCard(
    leading: IconChip(icono, color: color),
    title: titulo,
    subtitle: detalle,
    trailing: Icon(
      LucideIcons.chevronRight,
      size: AppSizes.iconMd,
      color: context.palette.textMuted,
    ),
    onTap: () => context.push(ruta),
  );
}
