import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_client.dart';
import '../../../core/formatos/validadores.dart';
import '../../../core/sesion/sesion_providers.dart' hide Empresa;
import '../../../core/widgets/widgets.dart';
import '../data/ajustes_repository.dart';
import '../domain/ajustes_models.dart';

class EmpresaScreen extends ConsumerWidget {
  const EmpresaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    body: Column(
      children: [
        const AppHeader(title: 'Empresa'),
        Expanded(
          child: ContenidoAsync<DatosEmpresa>(
            valor: ref.watch(datosEmpresaProvider),
            onReintentar: () => ref.invalidate(datosEmpresaProvider),
            builder: (datos) => _FormularioEmpresa(datos: datos),
          ),
        ),
      ],
    ),
  );
}

class _FormularioEmpresa extends ConsumerStatefulWidget {
  const _FormularioEmpresa({required this.datos});

  final DatosEmpresa datos;

  @override
  ConsumerState<_FormularioEmpresa> createState() => _FormularioEmpresaState();
}

class _FormularioEmpresaState extends ConsumerState<_FormularioEmpresa> {
  final _formulario = GlobalKey<FormState>();
  late final _ruc = TextEditingController(text: widget.datos.ruc);
  late final _razonSocial = TextEditingController(
    text: widget.datos.razonSocial,
  );
  late final _nombreComercial = TextEditingController(
    text: widget.datos.nombreComercial,
  );
  late final _direccion = TextEditingController(text: widget.datos.direccion);
  late final _ubigeo = TextEditingController(text: widget.datos.ubigeo);
  late final _departamento = TextEditingController(
    text: widget.datos.departamento,
  );
  late final _provincia = TextEditingController(text: widget.datos.provincia);
  late final _distrito = TextEditingController(text: widget.datos.distrito);
  late final _telefono = TextEditingController(text: widget.datos.telefono);
  late final _correo = TextEditingController(text: widget.datos.correo);
  late String? _logoPath = widget.datos.logoPath;
  late String _plantilla = widget.datos.plantillaPdf;
  bool _guardando = false;
  bool _subiendoLogo = false;

  @override
  void dispose() {
    for (final controlador in [
      _ruc,
      _razonSocial,
      _nombreComercial,
      _direccion,
      _ubigeo,
      _departamento,
      _provincia,
      _distrito,
      _telefono,
      _correo,
    ]) {
      controlador.dispose();
    }
    super.dispose();
  }

  String? _textoONulo(TextEditingController controlador) {
    final texto = controlador.text.trim();
    return texto.isEmpty ? null : texto;
  }

  Future<void> _elegirLogo() async {
    final imagen = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
    );
    if (imagen == null || !mounted) return;
    setState(() => _subiendoLogo = true);
    try {
      final contenido = await imagen.readAsBytes();
      final ruta = await ref
          .read(ajustesRepositoryProvider)
          .subirLogo(contenido: contenido, nombreArchivo: imagen.name);
      if (mounted) setState(() => _logoPath = ruta);
    } catch (_) {
      if (mounted) {
        mostrarMensaje(context, 'No se pudo subir el logo.', error: true);
      }
    } finally {
      if (mounted) setState(() => _subiendoLogo = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await ref.read(ajustesRepositoryProvider).guardarEmpresa({
        'ruc': _ruc.text.trim(),
        'razon_social': _razonSocial.text.trim(),
        'nombre_comercial': _textoONulo(_nombreComercial),
        'direccion': _textoONulo(_direccion),
        'ubigeo': _textoONulo(_ubigeo),
        'departamento': _textoONulo(_departamento),
        'provincia': _textoONulo(_provincia),
        'distrito': _textoONulo(_distrito),
        'telefono': _textoONulo(_telefono),
        'correo': _textoONulo(_correo),
        'logo_path': _logoPath,
        'plantilla_pdf': _plantilla,
      });
      ref.invalidate(datosEmpresaProvider);
      ref.invalidate(empresaActualProvider);
      if (mounted) mostrarMensaje(context, 'Datos de la empresa guardados.');
    } catch (error) {
      if (mounted) mostrarMensaje(context, mensajeDeError(error), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = ref.watch(rolActualProvider) == RolUsuario.admin;
    final logo = _logoPath;
    const separacion = SizedBox(height: AppSpace.x3);
    final p = context.palette;
    Widget seccion(String titulo, List<Widget> hijos) => Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.x3),
      child: SectionCard(
        title: titulo,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: hijos,
        ),
      ),
    );
    return Form(
      key: _formulario,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpace.x4),
              children: [
                seccion('Logo', [
                  Center(
                    child: Container(
                      width: 120,
                      height: 120,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: p.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppV2.cardRadius),
                        border: Border.all(color: p.border),
                      ),
                      child: logo == null
                          ? Icon(
                              LucideIcons.image,
                              size: 40,
                              color: p.textMuted,
                            )
                          : Image.network(
                              ref
                                  .read(ajustesRepositoryProvider)
                                  .urlPublicaImagen(logo),
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Icon(
                                LucideIcons.imageOff,
                                size: 40,
                                color: p.textMuted,
                              ),
                            ),
                    ),
                  ),
                  separacion,
                  BotonSecundario(
                    texto: logo == null ? 'Subir logo' : 'Cambiar logo',
                    icono: LucideIcons.imagePlus,
                    cargando: _subiendoLogo,
                    onPressed: _elegirLogo,
                  ),
                ]),
                seccion('Datos fiscales', [
                  CampoTexto(
                    etiqueta: 'RUC',
                    controller: _ruc,
                    teclado: TextInputType.number,
                    longitudMaxima: 11,
                    formateadores: [FilteringTextInputFormatter.digitsOnly],
                    validator: validarRuc,
                  ),
                  separacion,
                  CampoTexto(
                    etiqueta: 'Razón social',
                    controller: _razonSocial,
                    longitudMaxima: 300,
                    validator: validarRequerido,
                  ),
                  separacion,
                  CampoTexto(
                    etiqueta: 'Nombre comercial',
                    controller: _nombreComercial,
                    longitudMaxima: 200,
                  ),
                ]),
                seccion('Ubicación', [
                  CampoTexto(
                    etiqueta: 'Dirección fiscal',
                    controller: _direccion,
                    longitudMaxima: 300,
                  ),
                  separacion,
                  CampoTexto(
                    etiqueta: 'Ubigeo',
                    controller: _ubigeo,
                    teclado: TextInputType.number,
                    longitudMaxima: 6,
                    formateadores: [FilteringTextInputFormatter.digitsOnly],
                    validator: (valor) =>
                        (valor?.isEmpty ?? true) ? null : validarUbigeo(valor),
                  ),
                  separacion,
                  CampoTexto(
                    etiqueta: 'Departamento',
                    controller: _departamento,
                    longitudMaxima: 100,
                  ),
                  separacion,
                  CampoTexto(
                    etiqueta: 'Provincia',
                    controller: _provincia,
                    longitudMaxima: 100,
                  ),
                  separacion,
                  CampoTexto(
                    etiqueta: 'Distrito',
                    controller: _distrito,
                    longitudMaxima: 100,
                  ),
                ]),
                seccion('Contacto', [
                  CampoTexto(
                    etiqueta: 'Teléfono',
                    controller: _telefono,
                    teclado: TextInputType.phone,
                    longitudMaxima: 30,
                  ),
                  separacion,
                  CampoTexto(
                    etiqueta: 'Correo',
                    controller: _correo,
                    teclado: TextInputType.emailAddress,
                    validator: validarCorreoOpcional,
                  ),
                ]),
                if (esAdmin)
                  seccion('Plantilla de comprobantes', [
                    RadioGroup<String>(
                      groupValue: _plantilla,
                      onChanged: (valor) {
                        if (valor != null) setState(() => _plantilla = valor);
                      },
                      child: Column(
                        children: [
                          for (final plantilla in plantillasPdf)
                            RadioListTile<String>(
                              contentPadding: EdgeInsets.zero,
                              value: plantilla.valor,
                              title: Text(plantilla.etiqueta),
                              subtitle: Text(plantilla.descripcion),
                            ),
                        ],
                      ),
                    ),
                  ]),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.x4),
                child: BotonPrimario(
                  texto: 'Guardar',
                  cargando: _guardando,
                  onPressed: _subiendoLogo ? null : _guardar,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
