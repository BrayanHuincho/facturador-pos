import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_client.dart';
import '../../../core/formatos/formatos.dart';
import '../../../core/router/rutas.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/widgets.dart';
import '../data/ajustes_repository.dart';
import '../domain/ajustes_models.dart';

class SunatScreen extends ConsumerWidget {
  const SunatScreen({super.key});

  void _recargar(WidgetRef ref) {
    ref.invalidate(estadoSunatProvider);
    ref.invalidate(datosEmpresaProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(estadoSunatProvider);
    final empresa = ref.watch(datosEmpresaProvider);
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(title: 'SUNAT'),
          Expanded(
            child: ContenidoAsync<EstadoSunat>(
              valor: estado,
              onReintentar: () => _recargar(ref),
              builder: (datosEstado) => ContenidoAsync<DatosEmpresa>(
                valor: empresa,
                onReintentar: () => _recargar(ref),
                builder: (datosEmpresa) => ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _TarjetaEntorno(estado: datosEstado),
                    const SizedBox(height: 16),
                    _TarjetaCredenciales(estado: datosEstado),
                    const SizedBox(height: 16),
                    _TarjetaCertificado(estado: datosEstado),
                    const SizedBox(height: 16),
                    const _TarjetaPrueba(),
                    const SizedBox(height: 16),
                    _TarjetaCambioEntorno(
                      estado: datosEstado,
                      empresa: datosEmpresa,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.children});

  final String titulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: titulo,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _EstadoConfigurado extends StatelessWidget {
  const _EstadoConfigurado({required this.etiqueta, required this.configurado});

  final String etiqueta;
  final bool configurado;

  @override
  Widget build(BuildContext context) {
    final colores = context.coloresPos;
    final color = configurado ? colores.exito : colores.advertencia;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            configurado ? LucideIcons.circleCheck : LucideIcons.circleAlert,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$etiqueta: ${configurado ? 'configurado' : 'sin configurar'}',
              style: context.textos.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({
    required this.texto,
    required this.color,
    required this.fondo,
    required this.icono,
  });

  final String texto;
  final Color color;
  final Color fondo;
  final IconData icono;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: fondo,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: context.textos.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    ),
  );
}

class _TarjetaEntorno extends StatelessWidget {
  const _TarjetaEntorno({required this.estado});

  final EstadoSunat estado;

  @override
  Widget build(BuildContext context) {
    final colores = context.coloresPos;
    final produccion = estado.enProduccion;
    final color = produccion ? colores.exito : colores.advertencia;
    final fondo = produccion ? colores.exitoFondo : colores.advertenciaFondo;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            produccion ? LucideIcons.badgeCheck : LucideIcons.flaskConical,
            size: 36,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produccion ? 'PRODUCCIÓN' : 'BETA',
                  style: context.textos.headlineSmall?.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  produccion
                      ? 'Los comprobantes se envían a SUNAT y tienen validez tributaria.'
                      : 'Modo de pruebas: los comprobantes no tienen validez tributaria.',
                  style: context.textos.bodyMedium?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaCredenciales extends ConsumerStatefulWidget {
  const _TarjetaCredenciales({required this.estado});

  final EstadoSunat estado;

  @override
  ConsumerState<_TarjetaCredenciales> createState() =>
      _TarjetaCredencialesState();
}

class _TarjetaCredencialesState extends ConsumerState<_TarjetaCredenciales> {
  final _formulario = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  final _greClientId = TextEditingController();
  final _greClientSecret = TextEditingController();
  late String _envioBoletas = widget.estado.envioBoletas;
  bool _guardando = false;

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    _greClientId.dispose();
    _greClientSecret.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    final usuarioEscrito = _usuario.text.trim();
    final claveEscrita = _clave.text;
    final greIdEscrito = _greClientId.text.trim();
    final greSecretoEscrito = _greClientSecret.text;
    final sinCambios =
        usuarioEscrito.isEmpty &&
        claveEscrita.isEmpty &&
        greIdEscrito.isEmpty &&
        greSecretoEscrito.isEmpty &&
        _envioBoletas == widget.estado.envioBoletas;
    if (sinCambios) {
      mostrarMensaje(context, 'No hay cambios para guardar.');
      return;
    }
    setState(() => _guardando = true);
    try {
      await ref
          .read(ajustesRepositoryProvider)
          .guardarCredencialesSunat(
            usuarioSol: usuarioEscrito.isEmpty
                ? widget.estado.usuarioSol!
                : usuarioEscrito,
            claveSol: claveEscrita.isEmpty ? null : claveEscrita,
            envioBoletas: _envioBoletas,
            greClientId: greIdEscrito.isEmpty ? null : greIdEscrito,
            greClientSecret: greSecretoEscrito.isEmpty
                ? null
                : greSecretoEscrito,
          );
      _usuario.clear();
      _clave.clear();
      _greClientId.clear();
      _greClientSecret.clear();
      ref.invalidate(estadoSunatProvider);
      if (mounted) mostrarMensaje(context, 'Credenciales guardadas.');
    } catch (error) {
      if (mounted) mostrarMensaje(context, mensajeDeError(error), error: true);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    return _Seccion(
      titulo: 'Credenciales SOL',
      children: [
        _EstadoConfigurado(
          etiqueta: 'Usuario SOL',
          configurado: estado.tieneUsuarioSol,
        ),
        _EstadoConfigurado(
          etiqueta: 'Clave SOL',
          configurado: estado.tieneClaveSol,
        ),
        _EstadoConfigurado(
          etiqueta: 'Credenciales de guías (GRE)',
          configurado: estado.tieneGre,
        ),
        if (estado.tieneUsuarioSol)
          Text('Usuario actual: ${estado.usuarioSol}'),
        const SizedBox(height: 8),
        Form(
          key: _formulario,
          child: Column(
            children: [
              CampoTexto(
                etiqueta: estado.tieneUsuarioSol
                    ? 'Nuevo usuario SOL'
                    : 'Usuario SOL',
                controller: _usuario,
                ayuda: estado.tieneUsuarioSol
                    ? 'Déjalo vacío para conservar el actual.'
                    : null,
                longitudMaxima: 30,
                capitalizacion: TextCapitalization.characters,
                validator: (valor) =>
                    !estado.tieneUsuarioSol && (valor?.trim().isEmpty ?? true)
                    ? 'Escribe el usuario SOL'
                    : null,
              ),
              const SizedBox(height: 12),
              CampoTexto(
                etiqueta: estado.tieneClaveSol
                    ? 'Nueva clave SOL'
                    : 'Clave SOL',
                controller: _clave,
                esClave: true,
                longitudMaxima: 100,
                ayuda: estado.tieneClaveSol
                    ? 'Déjala vacía para conservar la actual.'
                    : null,
              ),
              const SizedBox(height: 12),
              CampoTexto(
                etiqueta: 'Client ID de guías (GRE)',
                controller: _greClientId,
                longitudMaxima: 200,
                ayuda: estado.tieneGre
                    ? 'Déjalo vacío para conservar el actual.'
                    : 'Se obtiene en SUNAT Operaciones en Línea.',
              ),
              const SizedBox(height: 12),
              CampoTexto(
                etiqueta: 'Client secret de guías (GRE)',
                controller: _greClientSecret,
                esClave: true,
                longitudMaxima: 500,
                ayuda: estado.tieneGre
                    ? 'Déjalo vacío para conservar el actual.'
                    : null,
              ),
              const SizedBox(height: 12),
              AppSelectorField<String>(
                titulo: 'Envío de boletas',
                icono: LucideIcons.send,
                initialValue: _envioBoletas,
                etiqueta: 'Envío de boletas',
                opciones: const [
                  AppSelectorOption(
                    value: 'individual',
                    label: 'Una por una, al emitir',
                  ),
                  AppSelectorOption(
                    value: 'resumen_diario',
                    label: 'Resumen diario',
                  ),
                ],
                onChanged: (valor) {
                  if (valor != null) setState(() => _envioBoletas = valor);
                },
              ),
              const SizedBox(height: 12),
              BotonPrimario(
                texto: 'Guardar credenciales',
                cargando: _guardando,
                onPressed: _guardar,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TarjetaCertificado extends ConsumerStatefulWidget {
  const _TarjetaCertificado({required this.estado});

  final EstadoSunat estado;

  @override
  ConsumerState<_TarjetaCertificado> createState() =>
      _TarjetaCertificadoState();
}

class _TarjetaCertificadoState extends ConsumerState<_TarjetaCertificado> {
  final _clave = TextEditingController();
  String? _nombreArchivo;
  Uint8List? _contenido;
  bool _ocupado = false;

  bool get _requiereClave =>
      !(_nombreArchivo?.toLowerCase().endsWith('.pem') ?? false);

  @override
  void dispose() {
    _clave.dispose();
    super.dispose();
  }

  Future<void> _elegirArchivo() async {
    try {
      final archivos = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pfx', 'p12', 'pem'],
      );
      if (archivos.isEmpty) return;
      final archivo = archivos.first;
      final contenido = await archivo.xFile.readAsBytes();
      if (!mounted) return;
      setState(() {
        _nombreArchivo = archivo.name;
        _contenido = contenido;
      });
    } on PlatformException {
      if (mounted) {
        mostrarMensaje(context, 'No se pudo abrir el archivo.', error: true);
      }
    }
  }

  Future<void> _subir() async {
    final contenido = _contenido;
    final nombre = _nombreArchivo;
    if (contenido == null || nombre == null) return;
    if (_requiereClave && _clave.text.isEmpty) {
      mostrarMensaje(
        context,
        'Escribe la contraseña del certificado.',
        error: true,
      );
      return;
    }
    setState(() => _ocupado = true);
    try {
      await ref
          .read(ajustesRepositoryProvider)
          .subirCertificado(
            contenido: contenido,
            nombreArchivo: nombre,
            clave: _clave.text,
          );
      _clave.clear();
      if (mounted) {
        setState(() {
          _contenido = null;
          _nombreArchivo = null;
        });
        mostrarMensaje(context, 'Certificado guardado.');
      }
      ref.invalidate(estadoSunatProvider);
    } catch (error) {
      if (mounted) mostrarMensaje(context, mensajeDeError(error), error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _eliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AppDialog(
        title: const Text('Eliminar certificado'),
        content: const Text(
          'Deberás subir otro certificado antes de pasar a producción.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _ocupado = true);
    try {
      await ref.read(ajustesRepositoryProvider).eliminarCertificado();
      ref.invalidate(estadoSunatProvider);
    } catch (error) {
      if (mounted) mostrarMensaje(context, mensajeDeError(error), error: true);
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget? _avisoVencimiento(BuildContext context) {
    final estado = widget.estado;
    final vence = estado.certificadoVenceEn;
    if (vence == null) return null;
    final ahora = DateTime.now();
    if (estado.certificadoVencido(ahora)) {
      return _Aviso(
        texto:
            'El certificado venció el ${formatearFecha(vence)}. Sube uno vigente.',
        color: context.colores.onErrorContainer,
        fondo: context.colores.errorContainer,
        icono: LucideIcons.shieldX,
      );
    }
    if (estado.certificadoPorVencer(ahora)) {
      final dias = vence.difference(ahora).inDays;
      return _Aviso(
        texto: dias == 0
            ? 'El certificado vence hoy. Renuévalo cuanto antes.'
            : 'El certificado vence en $dias ${dias == 1 ? 'día' : 'días'}. Renuévalo a tiempo.',
        color: context.coloresPos.advertencia,
        fondo: context.coloresPos.advertenciaFondo,
        icono: LucideIcons.triangleAlert,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    final vence = estado.certificadoVenceEn;
    final aviso = _avisoVencimiento(context);
    return _Seccion(
      titulo: 'Certificado digital',
      children: [
        _EstadoConfigurado(
          etiqueta: 'Certificado',
          configurado: estado.tieneCertificado,
        ),
        if (estado.certificadoTitular != null)
          Text('Titular: ${estado.certificadoTitular}'),
        if (vence != null) ...[
          const SizedBox(height: 4),
          Text('Vence: ${formatearFecha(vence)}'),
        ],
        if (aviso != null) ...[const SizedBox(height: 12), aviso],
        const SizedBox(height: 12),
        BotonSecundario(
          texto: _nombreArchivo ?? 'Elegir archivo .pfx, .p12 o .pem',
          icono: LucideIcons.fileUp,
          onPressed: _ocupado ? null : _elegirArchivo,
        ),
        if (_contenido != null) ...[
          const SizedBox(height: 12),
          CampoTexto(
            etiqueta: _requiereClave
                ? 'Contraseña del certificado'
                : 'Contraseña de la clave (si tiene)',
            controller: _clave,
            esClave: true,
          ),
          const SizedBox(height: 12),
          BotonPrimario(
            texto: 'Subir certificado',
            cargando: _ocupado,
            onPressed: _subir,
          ),
        ],
        if (estado.tieneCertificado && !estado.enProduccion) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: _ocupado ? null : _eliminar,
            child: const Text('Eliminar certificado'),
          ),
        ],
      ],
    );
  }
}

class _TarjetaPrueba extends ConsumerStatefulWidget {
  const _TarjetaPrueba();

  @override
  ConsumerState<_TarjetaPrueba> createState() => _TarjetaPruebaState();
}

class _TarjetaPruebaState extends ConsumerState<_TarjetaPrueba> {
  bool _probando = false;
  ResultadoPruebaSunat? _resultado;

  Future<void> _probar() async {
    setState(() {
      _probando = true;
      _resultado = null;
    });
    try {
      final resultado = await ref
          .read(ajustesRepositoryProvider)
          .probarConexion();
      if (mounted) setState(() => _resultado = resultado);
    } catch (error) {
      if (mounted) mostrarMensaje(context, mensajeDeError(error), error: true);
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultado = _resultado;
    return _Seccion(
      titulo: 'Prueba de conexión',
      children: [
        BotonSecundario(
          texto: 'Probar conexión',
          icono: LucideIcons.radioTower,
          cargando: _probando,
          onPressed: _probar,
        ),
        if (resultado != null) ...[
          const SizedBox(height: 12),
          Text(resultado.mensaje, style: context.textos.titleSmall),
          const SizedBox(height: 8),
          for (final paso in resultado.pasos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    paso.ok ? LucideIcons.circleCheck : LucideIcons.circleX,
                    size: 20,
                    color: paso.ok
                        ? context.coloresPos.exito
                        : context.colores.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(paso.paso, style: context.textos.titleSmall),
                        Text(paso.detalle),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _TarjetaCambioEntorno extends ConsumerStatefulWidget {
  const _TarjetaCambioEntorno({required this.estado, required this.empresa});

  final EstadoSunat estado;
  final DatosEmpresa empresa;

  @override
  ConsumerState<_TarjetaCambioEntorno> createState() =>
      _TarjetaCambioEntornoState();
}

class _TarjetaCambioEntornoState extends ConsumerState<_TarjetaCambioEntorno> {
  bool _cambiando = false;

  Future<void> _aplicar(String entorno, String? confirmarRuc) async {
    setState(() => _cambiando = true);
    try {
      await ref
          .read(ajustesRepositoryProvider)
          .cambiarEntorno(entorno: entorno, confirmarRuc: confirmarRuc);
      ref.invalidate(estadoSunatProvider);
      if (mounted) {
        mostrarMensaje(
          context,
          entorno == 'produccion'
              ? 'La empresa ya emite en producción.'
              : 'La empresa volvió a beta.',
        );
      }
    } catch (error) {
      if (mounted) mostrarMensaje(context, mensajeDeError(error), error: true);
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  Future<void> _volverABeta() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AppDialog(
        title: const Text('Volver a beta'),
        content: const Text(
          'Los comprobantes que emitas desde ahora no tendrán validez tributaria.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Volver a beta'),
          ),
        ],
      ),
    );
    if (confirmado == true && mounted) await _aplicar('beta', null);
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    if (estado.enProduccion) {
      return _Seccion(
        titulo: 'Entorno',
        children: [
          BotonSecundario(
            texto: 'Volver a beta',
            cargando: _cambiando,
            onPressed: _volverABeta,
          ),
        ],
      );
    }
    final faltantes = estado.requisitosFaltantes(
      rucEmpresa: widget.empresa.ruc,
      ahora: DateTime.now(),
    );
    return _Seccion(
      titulo: 'Paso a producción',
      children: [
        if (faltantes.isEmpty)
          const Text('Todos los requisitos están completos.')
        else ...[
          const Text('Para pasar a producción:'),
          const SizedBox(height: 8),
          for (final requisito in faltantes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.x, size: 20, color: context.colores.error),
                  const SizedBox(width: 8),
                  Expanded(child: Text(requisito.descripcion)),
                ],
              ),
            ),
        ],
        const SizedBox(height: 12),
        BotonPrimario(
          texto: 'Pasar a producción',
          icono: LucideIcons.rocket,
          onPressed: () => context.push(Rutas.ajustesProduccion),
        ),
      ],
    );
  }
}
