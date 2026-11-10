import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_client.dart';
import '../../../core/formatos/validadores.dart';
import '../../../core/sesion/sesion_providers.dart' hide Empresa;
import '../../../core/widgets/widgets.dart';
import '../data/ajustes_repository.dart';
import '../domain/ajustes_models.dart';

enum _AccionUsuario { cambiarRol, cambiarActivo }

class UsuariosScreen extends ConsumerWidget {
  const UsuariosScreen({super.key});

  Future<void> _actualizar(
    BuildContext context,
    WidgetRef ref,
    UsuarioSistema usuario,
    Map<String, dynamic> cambios,
  ) async {
    try {
      await ref
          .read(ajustesRepositoryProvider)
          .actualizarUsuario(usuario.id, cambios);
      ref.invalidate(usuariosProvider);
    } catch (error) {
      if (context.mounted) {
        mostrarMensaje(context, mensajeDeError(error), error: true);
      }
    }
  }

  Future<void> _cambiarRol(
    BuildContext context,
    WidgetRef ref,
    UsuarioSistema usuario,
  ) async {
    final rol = await showDialog<RolUsuario>(
      context: context,
      builder: (dialogo) => SimpleDialog(
        title: Text('Rol de ${usuario.nombre}'),
        children: [
          for (final opcion in RolUsuario.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogo).pop(opcion),
              child: Text(opcion.etiqueta),
            ),
        ],
      ),
    );
    if (rol == null || rol.name == usuario.rol || !context.mounted) return;
    await _actualizar(context, ref, usuario, {'rol': rol.name});
  }

  Future<void> _cambiarActivo(
    BuildContext context,
    WidgetRef ref,
    UsuarioSistema usuario,
  ) async {
    if (usuario.activo) {
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (dialogo) => AppDialog(
          title: const Text('Desactivar usuario'),
          content: Text('${usuario.nombre} ya no podrá ingresar al sistema.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogo).pop(true),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (confirmado != true || !context.mounted) return;
    }
    await _actualizar(context, ref, usuario, {'activo': !usuario.activo});
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuarioActualId = ref.watch(usuarioIdProvider);
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Usuarios',
            actions: [
              AppHeaderAction(
                icon: LucideIcons.userPlus,
                tooltip: 'Nuevo usuario',
                label: 'Crear',
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => const _DialogoNuevoUsuario(),
                ),
              ),
            ],
          ),
          Expanded(
            child: ContenidoAsync<List<UsuarioSistema>>(
              valor: ref.watch(usuariosProvider),
              onReintentar: () => ref.invalidate(usuariosProvider),
              builder: (usuarios) => ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.x4,
                  AppSpace.x4,
                  AppSpace.x4,
                  AppSpace.x6,
                ),
                itemCount: usuarios.length,
                itemBuilder: (_, indice) {
                  final usuario = usuarios[indice];
                  final esPropio = usuario.id == usuarioActualId;
                  final rol = RolUsuario.desde(usuario.rol).etiqueta;
                  return ListCard(
                    margin: const EdgeInsets.only(bottom: AppSpace.x2 + 2),
                    dimmed: !usuario.activo,
                    leading: AvatarIniciales(
                      nombre: usuario.nombre,
                      onLight: true,
                    ),
                    title: esPropio ? '${usuario.nombre} (tú)' : usuario.nombre,
                    subtitle:
                        '${usuario.correo ?? 'Sin correo'}\n$rol${usuario.activo ? '' : ' · Inactivo'}',
                    trailing: esPropio
                        ? null
                        : PopupMenuButton<_AccionUsuario>(
                            onSelected: (accion) => switch (accion) {
                              _AccionUsuario.cambiarRol => _cambiarRol(
                                context,
                                ref,
                                usuario,
                              ),
                              _AccionUsuario.cambiarActivo => _cambiarActivo(
                                context,
                                ref,
                                usuario,
                              ),
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: _AccionUsuario.cambiarRol,
                                child: Text('Cambiar rol'),
                              ),
                              PopupMenuItem(
                                value: _AccionUsuario.cambiarActivo,
                                child: Text(
                                  usuario.activo ? 'Desactivar' : 'Activar',
                                ),
                              ),
                            ],
                          ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogoNuevoUsuario extends ConsumerStatefulWidget {
  const _DialogoNuevoUsuario();

  @override
  ConsumerState<_DialogoNuevoUsuario> createState() =>
      _DialogoNuevoUsuarioState();
}

class _DialogoNuevoUsuarioState extends ConsumerState<_DialogoNuevoUsuario> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  RolUsuario _rol = RolUsuario.cajero;
  String? _establecimientoId;
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await ref
          .read(ajustesRepositoryProvider)
          .crearUsuario(
            nombre: _nombre.text.trim(),
            correo: _correo.text.trim(),
            clave: _clave.text,
            rol: _rol.name,
            establecimientoId: _establecimientoId,
          );
      ref.invalidate(usuariosProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        mostrarMensaje(context, mensajeDeError(error), error: true);
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final establecimientos =
        ref.watch(establecimientosProvider).value ?? const <Establecimiento>[];
    return AppDialog(
      title: const Text('Nuevo usuario'),
      content: Form(
        key: _formulario,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CampoTexto(
                etiqueta: 'Nombre',
                controller: _nombre,
                longitudMaxima: 200,
                validator: validarRequerido,
              ),
              const SizedBox(height: AppSpace.x4),
              CampoTexto(
                etiqueta: 'Correo',
                controller: _correo,
                teclado: TextInputType.emailAddress,
                validator: validarCorreo,
              ),
              const SizedBox(height: AppSpace.x4),
              CampoTexto(
                etiqueta: 'Contraseña inicial',
                controller: _clave,
                esClave: true,
                longitudMaxima: 72,
                validator: validarClaveNueva,
              ),
              const SizedBox(height: AppSpace.x4),
              _Etiquetado(
                'Rol',
                AppSelectorField<RolUsuario>(
                  titulo: 'Rol',
                  icono: LucideIcons.shieldCheck,
                  initialValue: _rol,
                  opciones: [
                    for (final rol in RolUsuario.values)
                      AppSelectorOption(value: rol, label: rol.etiqueta),
                  ],
                  onChanged: (valor) {
                    if (valor != null) setState(() => _rol = valor);
                  },
                ),
              ),
              if (establecimientos.length > 1) ...[
                const SizedBox(height: AppSpace.x4),
                _Etiquetado(
                  'Establecimiento',
                  AppSelectorField<String>(
                    titulo: 'Establecimiento',
                    icono: LucideIcons.store,
                    initialValue: _establecimientoId,
                    ayuda: 'Si no eliges, se asigna el principal.',
                    opciones: [
                      for (final local in establecimientos)
                        AppSelectorOption(
                          value: local.id,
                          label: '${local.codigo} · ${local.nombre}',
                        ),
                    ],
                    onChanged: (valor) =>
                        setState(() => _establecimientoId = valor),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: _guardando ? null : _guardar,
          child: const Text('Crear'),
        ),
      ],
    );
  }
}

class _Etiquetado extends StatelessWidget {
  const _Etiquetado(this.etiqueta, this.hijo);

  final String etiqueta;
  final Widget hijo;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        etiqueta,
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: context.palette.text),
      ),
      const SizedBox(height: AppSpace.x1 + 2),
      hijo,
    ],
  );
}
