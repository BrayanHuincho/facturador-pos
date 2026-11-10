import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_client.dart';
import '../../../core/formatos/validadores.dart';
import '../../../core/sesion/sesion_providers.dart' hide Empresa;
import '../../../core/widgets/widgets.dart';
import '../data/ajustes_repository.dart';

const _tamanoAvatar = 112.0;

class PerfilScreen extends ConsumerStatefulWidget {
  const PerfilScreen({super.key});

  @override
  ConsumerState<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends ConsumerState<PerfilScreen> {
  final _formulario = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  bool _nombreCargado = false;
  bool _guardando = false;
  bool _ocupadoFoto = false;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  AjustesRepository get _repositorio => ref.read(ajustesRepositoryProvider);

  Future<void> _guardarNombre() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await _repositorio.actualizarNombrePerfil(_nombre.text.trim());
      ref.invalidate(perfilActualProvider);
      if (mounted) mostrarMensaje(context, 'Nombre actualizado.');
    } catch (error) {
      if (mounted) mostrarMensaje(context, mensajeDeError(error), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _elegirFoto() async {
    final imagen = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (imagen == null || !mounted) return;
    await _cambiarFoto(() async {
      await _repositorio.subirFotoPerfil(
        contenido: await imagen.readAsBytes(),
        nombreArchivo: imagen.name,
      );
    });
  }

  Future<void> _cambiarFoto(Future<void> Function() accion) async {
    setState(() => _ocupadoFoto = true);
    try {
      await accion();
      ref.invalidate(perfilActualProvider);
    } catch (error) {
      if (mounted) mostrarMensaje(context, mensajeDeError(error), error: true);
    } finally {
      if (mounted) setState(() => _ocupadoFoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(perfilActualProvider).value;
    final correo = ref.watch(supabaseProvider).auth.currentUser?.email;
    final t = Theme.of(context).textTheme;
    final p = context.palette;
    if (perfil != null && !_nombreCargado) {
      _nombreCargado = true;
      _nombre.text = perfil.nombre;
    }
    return Scaffold(
      backgroundColor: p.background,
      body: Column(
        children: [
          const AppHeader(title: 'Mi perfil'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.x4),
              children: [
                const SizedBox(height: AppSpace.x4),
                Center(
                  child: AvatarIniciales(
                    nombre: perfil?.nombre ?? '',
                    fotoUrl: perfil?.fotoUrl,
                    size: _tamanoAvatar,
                    onLight: true,
                  ),
                ),
                const SizedBox(height: AppSpace.x3),
                Text(
                  correo ?? '',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: p.textMuted),
                ),
                if (perfil != null)
                  Text(
                    perfil.rol.etiqueta,
                    textAlign: TextAlign.center,
                    style: t.bodySmall?.copyWith(color: p.textMuted),
                  ),
                const SizedBox(height: AppSpace.x4),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: perfil?.fotoPath == null
                            ? 'Subir foto'
                            : 'Cambiar foto',
                        icon: LucideIcons.camera,
                        variant: AppButtonVariant.secondary,
                        expand: true,
                        loading: _ocupadoFoto,
                        onPressed: _ocupadoFoto ? null : _elegirFoto,
                      ),
                    ),
                    if (perfil?.fotoPath != null) ...[
                      const SizedBox(width: AppSpace.x2),
                      Expanded(
                        child: AppButton(
                          label: 'Quitar foto',
                          icon: LucideIcons.trash2,
                          variant: AppButtonVariant.secondary,
                          expand: true,
                          onPressed: _ocupadoFoto
                              ? null
                              : () =>
                                    _cambiarFoto(_repositorio.quitarFotoPerfil),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpace.x6),
                Form(
                  key: _formulario,
                  child: CampoTexto(
                    etiqueta: 'Nombre para mostrar',
                    controller: _nombre,
                    longitudMaxima: 200,
                    capitalizacion: TextCapitalization.words,
                    validator: validarRequerido,
                  ),
                ),
                const SizedBox(height: AppSpace.x4),
                AppButton(
                  label: 'Guardar nombre',
                  expand: true,
                  loading: _guardando,
                  onPressed: _guardando ? null : _guardarNombre,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
