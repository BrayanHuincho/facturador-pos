import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/router/rutas.dart';
import '../../core/sesion/sesion_providers.dart';
import '../../design_system/design_system.dart';
import '../pos/presentation/pos_providers.dart';

class _Destino {
  const _Destino(this.etiqueta, this.icono, this.ruta, {this.color});

  final String etiqueta;
  final IconData icono;
  final String ruta;
  final Color? color;
}

const _comprobantes = _Destino(
  'Comprobantes',
  LucideIcons.receiptText,
  Rutas.comprobantes,
);
const _caja = _Destino('Caja', LucideIcons.wallet, Rutas.caja);
const _reportes = _Destino('Reportes', LucideIcons.chartColumn, Rutas.reportes);
const _productos = _Destino(
  'Productos',
  LucideIcons.package,
  Rutas.productos,
  color: Color(0xFFC2410C),
);
const _clientes = _Destino(
  'Clientes',
  LucideIcons.users,
  Rutas.clientes,
  color: Color(0xFF7C3AED),
);
const _guias = _Destino(
  'Guías',
  LucideIcons.truck,
  Rutas.guias,
  color: Color(0xFF0E7490),
);
const _ajustes = _Destino('Ajustes', LucideIcons.settings, Rutas.ajustes);
const _mas = _Destino('Más', LucideIcons.menu, '');

List<_Destino> _principales(RolUsuario? rol, ModulosEmpresa modulos) {
  if (rol == RolUsuario.contador) {
    return [
      _comprobantes,
      if (modulos.guias) _guias else if (modulos.reportes) _reportes,
      _mas,
    ];
  }
  final destinos = [
    _comprobantes,
    if (modulos.caja) _caja,
    if (modulos.guias) _guias,
    _productos,
    _clientes,
  ];
  return [...destinos.take(3), _mas];
}

const _secundarios = [_reportes, _productos, _clientes, _guias, _ajustes];

List<_Destino> _secundariosPara(
  List<_Destino> principales,
  ModulosEmpresa modulos,
  RolUsuario? rol,
) => [
  for (final destino in _secundarios)
    if (!principales.contains(destino) &&
        (destino != _guias || modulos.guias) &&
        (destino != _reportes ||
            (modulos.reportes && rol != RolUsuario.cajero)))
      destino,
];

bool _estaEn(String ubicacion, String ruta) =>
    ubicacion == ruta || ubicacion.startsWith('$ruta/');

class ShellPrincipal extends ConsumerWidget {
  const ShellPrincipal({
    required this.ubicacion,
    required this.child,
    super.key,
  });

  final String ubicacion;
  final Widget child;

  bool get _esPantallaRaiz => [
    Rutas.pos,
    Rutas.comprobantes,
    Rutas.caja,
    Rutas.reportes,
    ..._secundarios.map((destino) => destino.ruta),
  ].contains(ubicacion);

  int _indiceActual(List<_Destino> destinos) {
    if (_estaEn(ubicacion, Rutas.pos)) return -1;
    final indice = destinos.indexWhere(
      (destino) => destino.ruta.isNotEmpty && _estaEn(ubicacion, destino.ruta),
    );
    return indice >= 0 ? indice : destinos.length - 1;
  }

  void _seleccionar(
    BuildContext context,
    _Destino destino,
    RolUsuario? rolActual,
    ModulosEmpresa modulosActuales,
  ) {
    if (destino.ruta.isEmpty) {
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (_) => _HojaMas(
          contextoShell: context,
          secundarios: _secundariosPara(
            _principales(rolActual, modulosActuales),
            modulosActuales,
            rolActual,
          ),
        ),
      );
      return;
    }
    context.go(destino.ruta);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rol = ref.watch(rolActualProvider);
    final modulos = ref.watch(modulosEmpresaProvider);
    final destinos = _principales(rol, modulos);
    final indice = _indiceActual(destinos);
    final puedeVender = rol != RolUsuario.contador;
    final enCarrito = ref.watch(carritoProvider.select((c) => c.lineas.length));
    final items = [
      for (final destino in destinos)
        FabNavItem(icon: destino.icono, label: destino.etiqueta),
    ];
    void irAVender() => context.go(Rutas.pos);

    if (MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded) {
      return Scaffold(
        body: Row(
          children: [
            FabNavRail(
              items: items,
              currentIndex: indice,
              onTap: (i) => _seleccionar(context, destinos[i], rol, modulos),
              fabIcon: LucideIcons.shoppingCart,
              fabLabel: 'Vender',
              onFab: puedeVender ? irAVender : null,
              fabBadge: enCarrito,
            ),
            const VerticalDivider(width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: _esPantallaRaiz
          ? FabNavBar(
              items: items,
              currentIndex: indice,
              onTap: (i) => _seleccionar(context, destinos[i], rol, modulos),
              fabIcon: LucideIcons.shoppingCart,
              fabLabel: 'Vender',
              onFab: puedeVender ? irAVender : null,
              fabBadge: enCarrito,
            )
          : null,
    );
  }
}

class _HojaMas extends ConsumerWidget {
  const _HojaMas({required this.contextoShell, required this.secundarios});

  final BuildContext contextoShell;
  final List<_Destino> secundarios;

  void _ir(BuildContext context, String ruta) {
    Navigator.of(context).pop();
    contextoShell.go(ruta);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(perfilActualProvider).value;
    final empresa = ref.watch(empresaActualProvider).value;
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    const separacion = SizedBox(height: AppSpace.x2);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.x4,
          0,
          AppSpace.x4,
          AppSpace.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                AvatarIniciales(
                  nombre: perfil?.nombre ?? '',
                  fotoUrl: perfil?.fotoUrl,
                  onLight: true,
                ),
                const SizedBox(width: AppSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(perfil?.nombre ?? '', style: t.titleMedium),
                      Text(
                        [
                          ?perfil?.rol.etiqueta,
                          ?empresa?.nombreVisible,
                        ].join(' · '),
                        style: t.bodySmall?.copyWith(color: p.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.x4),
            ListCard(
              leading: const IconChip(LucideIcons.circleUser),
              title: 'Mi perfil',
              trailing: Icon(
                LucideIcons.chevronRight,
                size: AppSizes.iconMd,
                color: p.textMuted,
              ),
              onTap: () {
                Navigator.of(context).pop();
                contextoShell.push(Rutas.ajustesPerfil);
              },
            ),
            separacion,
            for (final destino in secundarios) ...[
              ListCard(
                leading: IconChip(destino.icono, color: destino.color),
                title: destino.etiqueta,
                trailing: Icon(
                  LucideIcons.chevronRight,
                  size: AppSizes.iconMd,
                  color: p.textMuted,
                ),
                onTap: () => _ir(context, destino.ruta),
              ),
              separacion,
            ],
            ListCard(
              leading: IconChip(LucideIcons.logOut, color: p.danger),
              title: 'Cerrar sesión',
              onTap: () {
                Navigator.of(context).pop();
                ref.read(controladorSesionProvider).cerrarSesion();
              },
            ),
          ],
        ),
      ),
    );
  }
}
