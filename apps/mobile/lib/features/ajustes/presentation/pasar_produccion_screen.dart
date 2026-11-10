import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errores/errores.dart';
import '../../../core/formatos/validadores.dart';
import '../../../core/widgets/widgets.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../data/ajustes_repository.dart';
import '../domain/ajustes_models.dart';

enum _Paso { empresa, sol, certificado, confirmacion }

class PasarProduccionScreen extends ConsumerStatefulWidget {
  const PasarProduccionScreen({super.key});

  @override
  ConsumerState<PasarProduccionScreen> createState() =>
      _PasarProduccionScreenState();
}

class _PasarProduccionScreenState extends ConsumerState<PasarProduccionScreen> {
  _Paso? _elegido;

  void _recargar() {
    ref.invalidate(estadoSunatProvider);
    ref.invalidate(datosEmpresaProvider);
  }

  void _guardado() {
    setState(() => _elegido = null);
    _recargar();
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(estadoSunatProvider);
    final empresa = ref.watch(datosEmpresaProvider);
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(
            title: 'Pasar a producción',
            subtitle: 'Completa cada paso para emitir con validez',
          ),
          Expanded(
            child: ContenidoAsync<EstadoSunat>(
              valor: estado,
              onReintentar: _recargar,
              builder: (datosEstado) => ContenidoAsync<DatosEmpresa>(
                valor: empresa,
                onReintentar: _recargar,
                builder: (datosEmpresa) => _pasos(datosEstado, datosEmpresa),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pasos(EstadoSunat estado, DatosEmpresa empresa) {
    final ahora = DateTime.now();
    final faltantes = estado.requisitosFaltantes(
      rucEmpresa: empresa.ruc,
      ahora: ahora,
    );
    final completos = <_Paso, bool>{
      _Paso.empresa:
          empresa.ruc.isNotEmpty && empresa.ruc != rucEmpresaDePrueba,
      _Paso.sol: estado.tieneUsuarioSol && estado.tieneClaveSol,
      _Paso.certificado:
          estado.tieneCertificado && !estado.certificadoVencido(ahora),
      _Paso.confirmacion: false,
    };
    final primero = _Paso.values.firstWhere((p) => !(completos[p] ?? false));
    final abierto = _elegido ?? primero;

    Widget paso(
      _Paso clave,
      String titulo,
      String detalle,
      IconData icono,
      Widget contenido,
    ) => _TarjetaPaso(
      numero: clave.index + 1,
      titulo: titulo,
      detalle: detalle,
      icono: icono,
      completo: completos[clave] ?? false,
      abierto: abierto == clave,
      alTocar: () => setState(() => _elegido = clave),
      child: contenido,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpace.x4),
      children: [
        paso(
          _Paso.empresa,
          'Datos reales de la empresa',
          'RUC, razón social, dirección y ubigeo',
          LucideIcons.building2,
          _FormularioEmpresa(empresa: empresa, alGuardar: _guardado),
        ),
        const SizedBox(height: AppSpace.x3),
        paso(
          _Paso.sol,
          'Usuario y clave SOL',
          'Tus accesos a SUNAT Operaciones en Línea',
          LucideIcons.keyRound,
          _FormularioSol(estado: estado, alGuardar: _guardado),
        ),
        const SizedBox(height: AppSpace.x3),
        paso(
          _Paso.certificado,
          'Certificado digital',
          'Archivo .pfx, .p12 o .pem de tu RUC',
          LucideIcons.fileBadge,
          _FormularioCertificado(estado: estado, alGuardar: _guardado),
        ),
        const SizedBox(height: AppSpace.x3),
        paso(
          _Paso.confirmacion,
          'Confirmación',
          'Escribe tu RUC para activar producción',
          LucideIcons.rocket,
          _Confirmacion(empresa: empresa, faltantes: faltantes),
        ),
      ],
    );
  }
}

class _TarjetaPaso extends StatelessWidget {
  const _TarjetaPaso({
    required this.numero,
    required this.titulo,
    required this.detalle,
    required this.icono,
    required this.completo,
    required this.abierto,
    required this.alTocar,
    required this.child,
  });

  final int numero;
  final String titulo;
  final String detalle;
  final IconData icono;
  final bool completo;
  final bool abierto;
  final VoidCallback alTocar;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    final color = completo ? p.success : p.warning;
    final fondo = completo ? p.successSoft : p.warningSoft;
    return DecoratedBox(
      decoration: v2CardDecoration(p, border: abierto ? p.brand : null),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppV2.cardRadius),
              onTap: alTocar,
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.x3),
                child: Row(
                  children: [
                    IconChip(
                      completo ? LucideIcons.check : icono,
                      color: completo ? p.success : p.brand,
                    ),
                    const SizedBox(width: AppSpace.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$numero. $titulo',
                            style: t.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            detalle,
                            style: t.bodySmall?.copyWith(color: p.textMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.x2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.x2,
                        vertical: AppSpace.x1,
                      ),
                      decoration: BoxDecoration(
                        color: fondo,
                        borderRadius: AppRadii.pillAll,
                      ),
                      child: Text(
                        completo ? 'Listo' : 'Pendiente',
                        style: t.labelSmall?.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (abierto)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.x3,
                  0,
                  AppSpace.x3,
                  AppSpace.x4,
                ),
                child: child,
              ),
          ],
        ),
      ),
    );
  }
}

class _FormularioEmpresa extends ConsumerStatefulWidget {
  const _FormularioEmpresa({required this.empresa, required this.alGuardar});

  final DatosEmpresa empresa;
  final VoidCallback alGuardar;

  @override
  ConsumerState<_FormularioEmpresa> createState() => _FormularioEmpresaState();
}

class _FormularioEmpresaState extends ConsumerState<_FormularioEmpresa> {
  final _formulario = GlobalKey<FormState>();
  late final bool _esPrueba = widget.empresa.ruc == rucEmpresaDePrueba;

  late final _ruc = TextEditingController(
    text: _esPrueba ? '' : widget.empresa.ruc,
  );
  late final _razonSocial = TextEditingController(
    text: _inicial(widget.empresa.razonSocial),
  );
  late final _nombreComercial = TextEditingController(
    text: _inicial(widget.empresa.nombreComercial),
  );
  late final _direccion = TextEditingController(
    text: _inicial(widget.empresa.direccion),
  );
  late final _ubigeo = TextEditingController(
    text: _inicial(widget.empresa.ubigeo),
  );
  late final _departamento = TextEditingController(
    text: _inicial(widget.empresa.departamento),
  );
  late final _provincia = TextEditingController(
    text: _inicial(widget.empresa.provincia),
  );
  late final _distrito = TextEditingController(
    text: _inicial(widget.empresa.distrito),
  );

  bool _buscando = false;
  bool _guardando = false;
  String? _error;

  String _inicial(String? valor) => _esPrueba ? '' : valor ?? '';

  @override
  void dispose() {
    for (final control in [
      _ruc,
      _razonSocial,
      _nombreComercial,
      _direccion,
      _ubigeo,
      _departamento,
      _provincia,
      _distrito,
    ]) {
      control.dispose();
    }
    super.dispose();
  }

  String? _validarRucReal(String? valor) {
    if (valor?.trim() == rucEmpresaDePrueba) {
      return 'Registra el RUC real de tu empresa';
    }
    return validarRuc(valor);
  }

  Future<void> _buscar() async {
    final problema = _validarRucReal(_ruc.text);
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    setState(() {
      _buscando = true;
      _error = null;
    });
    try {
      final datos = await ref
          .read(onboardingRepositoryProvider)
          .consultarRuc(_ruc.text.trim());
      _razonSocial.text = datos.razonSocial;
      _direccion.text = datos.direccion;
      _ubigeo.text = datos.ubigeo;
      _departamento.text = datos.departamento;
      _provincia.text = datos.provincia;
      _distrito.text = datos.distrito;
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              '${mensajeDeError(error)} También puedes completar los datos a mano.',
        );
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final comercial = _nombreComercial.text.trim();
      await ref.read(ajustesRepositoryProvider).guardarEmpresa({
        'ruc': _ruc.text.trim(),
        'razon_social': _razonSocial.text.trim(),
        'nombre_comercial': comercial.isEmpty
            ? _razonSocial.text.trim()
            : comercial,
        'direccion': _direccion.text.trim(),
        'ubigeo': _ubigeo.text.trim(),
        'departamento': _departamento.text.trim(),
        'provincia': _provincia.text.trim(),
        'distrito': _distrito.text.trim(),
      });
      final repositorio = ref.read(ajustesRepositoryProvider);
      final establecimientos = await repositorio.listarEstablecimientos();
      if (establecimientos.isNotEmpty) {
        final principal = establecimientos.firstWhere(
          (e) => e.codigo == '0000',
          orElse: () => establecimientos.first,
        );
        await repositorio.actualizarEstablecimiento(principal.id, {
          'direccion': _direccion.text.trim(),
          'ubigeo': _ubigeo.text.trim(),
        });
      }
      if (mounted) {
        mostrarMensaje(context, 'Datos de la empresa guardados.');
        widget.alGuardar();
      }
    } catch (error) {
      if (mounted) setState(() => _error = mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const separacion = SizedBox(height: AppSpace.x3);
    return Form(
      key: _formulario,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CampoTexto(
            etiqueta: 'RUC',
            controller: _ruc,
            teclado: TextInputType.number,
            longitudMaxima: 11,
            formateadores: [FilteringTextInputFormatter.digitsOnly],
            validator: _validarRucReal,
            onSubmitted: (_) => _buscar(),
            sufijo: _buscando
                ? const Padding(
                    padding: EdgeInsets.all(AppSpace.x3),
                    child: SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'Buscar RUC',
                    icon: const Icon(LucideIcons.search, size: AppSizes.iconMd),
                    onPressed: _buscar,
                  ),
          ),
          separacion,
          CampoTexto(
            etiqueta: 'Razón social',
            controller: _razonSocial,
            validator: validarRequerido,
          ),
          separacion,
          CampoTexto(
            etiqueta: 'Nombre comercial',
            controller: _nombreComercial,
            capitalizacion: TextCapitalization.words,
          ),
          separacion,
          CampoTexto(
            etiqueta: 'Dirección fiscal',
            controller: _direccion,
            validator: validarRequerido,
          ),
          separacion,
          CampoTexto(
            etiqueta: 'Ubigeo',
            controller: _ubigeo,
            teclado: TextInputType.number,
            longitudMaxima: 6,
            formateadores: [FilteringTextInputFormatter.digitsOnly],
            validator: validarUbigeo,
          ),
          separacion,
          CampoTexto(
            etiqueta: 'Departamento',
            controller: _departamento,
            validator: validarRequerido,
          ),
          separacion,
          CampoTexto(
            etiqueta: 'Provincia',
            controller: _provincia,
            validator: validarRequerido,
          ),
          separacion,
          CampoTexto(
            etiqueta: 'Distrito',
            controller: _distrito,
            validator: validarRequerido,
          ),
          if (_error != null) ...[separacion, _TextoError(_error!)],
          const SizedBox(height: AppSpace.x4),
          BotonPrimario(
            texto: 'Guardar datos',
            icono: LucideIcons.check,
            cargando: _guardando,
            onPressed: _guardar,
          ),
        ],
      ),
    );
  }
}

class _FormularioSol extends ConsumerStatefulWidget {
  const _FormularioSol({required this.estado, required this.alGuardar});

  final EstadoSunat estado;
  final VoidCallback alGuardar;

  @override
  ConsumerState<_FormularioSol> createState() => _FormularioSolState();
}

class _FormularioSolState extends ConsumerState<_FormularioSol> {
  final _formulario = GlobalKey<FormState>();
  final _usuario = TextEditingController();
  final _clave = TextEditingController();
  bool _guardando = false;
  String? _error;

  @override
  void dispose() {
    _usuario.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      final escrito = _usuario.text.trim();
      await ref
          .read(ajustesRepositoryProvider)
          .guardarCredencialesSunat(
            usuarioSol: escrito.isEmpty ? widget.estado.usuarioSol! : escrito,
            claveSol: _clave.text.isEmpty ? null : _clave.text,
            envioBoletas: widget.estado.envioBoletas,
          );
      if (mounted) {
        _clave.clear();
        mostrarMensaje(context, 'Credenciales guardadas.');
        widget.alGuardar();
      }
    } catch (error) {
      if (mounted) setState(() => _error = mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.estado;
    return Form(
      key: _formulario,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CampoTexto(
            etiqueta: 'Usuario SOL',
            controller: _usuario,
            longitudMaxima: 30,
            capitalizacion: TextCapitalization.characters,
            ayuda: estado.tieneUsuarioSol
                ? 'Actual: ${estado.usuarioSol}. Déjalo vacío para conservarlo.'
                : null,
            validator: (valor) =>
                !estado.tieneUsuarioSol && (valor?.trim().isEmpty ?? true)
                ? 'Escribe el usuario SOL'
                : null,
          ),
          const SizedBox(height: AppSpace.x3),
          CampoTexto(
            etiqueta: 'Clave SOL',
            controller: _clave,
            esClave: true,
            longitudMaxima: 100,
            ayuda: estado.tieneClaveSol
                ? 'Déjala vacía para conservar la actual.'
                : 'Se guarda cifrada y no se vuelve a mostrar.',
            validator: (valor) =>
                !estado.tieneClaveSol && (valor?.isEmpty ?? true)
                ? 'Escribe la clave SOL'
                : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.x3),
            _TextoError(_error!),
          ],
          const SizedBox(height: AppSpace.x4),
          BotonPrimario(
            texto: 'Guardar credenciales',
            icono: LucideIcons.check,
            cargando: _guardando,
            onPressed: _guardar,
          ),
        ],
      ),
    );
  }
}

class _FormularioCertificado extends ConsumerStatefulWidget {
  const _FormularioCertificado({required this.estado, required this.alGuardar});

  final EstadoSunat estado;
  final VoidCallback alGuardar;

  @override
  ConsumerState<_FormularioCertificado> createState() =>
      _FormularioCertificadoState();
}

class _FormularioCertificadoState
    extends ConsumerState<_FormularioCertificado> {
  final _clave = TextEditingController();
  String? _nombreArchivo;
  Uint8List? _contenido;
  bool _subiendo = false;
  String? _error;

  bool get _requiereClave =>
      !(_nombreArchivo?.toLowerCase().endsWith('.pem') ?? false);

  @override
  void dispose() {
    _clave.dispose();
    super.dispose();
  }

  Future<void> _elegir() async {
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
        _error = null;
      });
    } on PlatformException {
      if (mounted) setState(() => _error = 'No se pudo abrir el archivo.');
    }
  }

  Future<void> _subir() async {
    final contenido = _contenido;
    final nombre = _nombreArchivo;
    if (contenido == null || nombre == null) return;
    if (_requiereClave && _clave.text.isEmpty) {
      setState(() => _error = 'Escribe la contraseña del certificado.');
      return;
    }
    setState(() {
      _subiendo = true;
      _error = null;
    });
    try {
      await ref
          .read(ajustesRepositoryProvider)
          .subirCertificado(
            contenido: contenido,
            nombreArchivo: nombre,
            clave: _clave.text,
          );
      if (mounted) {
        _clave.clear();
        mostrarMensaje(context, 'Certificado guardado.');
        widget.alGuardar();
      }
    } catch (error) {
      if (mounted) setState(() => _error = mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titular = widget.estado.certificadoTitular;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (titular != null) ...[
          Text('Titular actual: $titular'),
          const SizedBox(height: AppSpace.x3),
        ],
        BotonSecundario(
          texto: _nombreArchivo ?? 'Elegir archivo',
          icono: LucideIcons.fileUp,
          onPressed: _subiendo ? null : _elegir,
        ),
        if (_contenido != null) ...[
          const SizedBox(height: AppSpace.x3),
          CampoTexto(
            etiqueta: _requiereClave
                ? 'Contraseña del certificado'
                : 'Contraseña de la clave (si tiene)',
            controller: _clave,
            esClave: true,
          ),
          const SizedBox(height: AppSpace.x4),
          BotonPrimario(
            texto: 'Subir certificado',
            icono: LucideIcons.upload,
            cargando: _subiendo,
            onPressed: _subir,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AppSpace.x3),
          _TextoError(_error!),
        ],
      ],
    );
  }
}

class _Confirmacion extends ConsumerStatefulWidget {
  const _Confirmacion({required this.empresa, required this.faltantes});

  final DatosEmpresa empresa;
  final List<RequisitoProduccion> faltantes;

  @override
  ConsumerState<_Confirmacion> createState() => _ConfirmacionState();
}

class _ConfirmacionState extends ConsumerState<_Confirmacion> {
  final _ruc = TextEditingController();
  bool _cambiando = false;
  String? _error;

  bool get _puedeCambiar =>
      widget.faltantes.isEmpty && _ruc.text.trim() == widget.empresa.ruc;

  @override
  void dispose() {
    _ruc.dispose();
    super.dispose();
  }

  Future<void> _activar() async {
    setState(() {
      _cambiando = true;
      _error = null;
    });
    try {
      await ref
          .read(ajustesRepositoryProvider)
          .cambiarEntorno(
            entorno: 'produccion',
            confirmarRuc: _ruc.text.trim(),
          );
      ref.invalidate(estadoSunatProvider);
      if (mounted) {
        mostrarMensaje(context, 'La empresa ya emite en producción.');
        context.pop();
      }
    } catch (error) {
      if (mounted) setState(() => _error = mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _cambiando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.faltantes.isNotEmpty) ...[
          Text(
            'Antes de continuar:',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpace.x2),
          for (final requisito in widget.faltantes)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.x2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.circleAlert,
                    size: AppSizes.iconMd,
                    color: p.warning,
                  ),
                  const SizedBox(width: AppSpace.x2),
                  Expanded(child: Text(requisito.descripcion)),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.x2),
        ] else ...[
          Text(
            'Los comprobantes de ${widget.empresa.razonSocial} se enviarán a '
            'SUNAT con validez tributaria real.',
          ),
          const SizedBox(height: AppSpace.x3),
          CampoTexto(
            etiqueta: 'Escribe el RUC ${widget.empresa.ruc}',
            controller: _ruc,
            teclado: TextInputType.number,
            longitudMaxima: 11,
            formateadores: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpace.x4),
        ],
        if (_error != null) ...[
          _TextoError(_error!),
          const SizedBox(height: AppSpace.x3),
        ],
        BotonPrimario(
          texto: 'Pasar a producción',
          icono: LucideIcons.rocket,
          cargando: _cambiando,
          onPressed: _puedeCambiar ? _activar : null,
        ),
      ],
    );
  }
}

class _TextoError extends StatelessWidget {
  const _TextoError(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: Theme.of(context).textTheme.bodyMedium
        ?.copyWith(color: context.palette.danger),
  );
}
