import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errores/errores.dart';
import '../../../core/formatos/validadores.dart';
import '../../../core/router/redireccion.dart';
import '../../../core/router/rutas.dart';
import '../../../core/sesion/sesion_providers.dart';
import '../../../core/tema/tema.dart';
import '../../../core/widgets/widgets.dart';
import '../data/onboarding_repository.dart';

const _titulosPasos = [
  'Datos de tu negocio',
  'Busca tu RUC',
  'Usuario SOL',
  'Certificado digital',
  'Entorno de emisión',
];

const _entornoBeta = 'beta';
const _entornoProduccion = 'produccion';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _formularios = List.generate(
    _titulosPasos.length,
    (_) => GlobalKey<FormState>(),
  );

  final _nombreComercial = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _nombreLocal = TextEditingController(text: 'Principal');
  final _ruc = TextEditingController();
  final _razonSocial = TextEditingController();
  final _direccion = TextEditingController();
  final _ubigeo = TextEditingController();
  final _departamento = TextEditingController();
  final _provincia = TextEditingController();
  final _distrito = TextEditingController();
  final _usuarioSol = TextEditingController();
  final _claveSol = TextEditingController();
  final _claveCertificado = TextEditingController();
  final _confirmarRuc = TextEditingController();

  int _paso = 0;
  bool _trabajando = false;
  bool _buscandoRuc = false;
  bool _empresaGuardada = false;
  bool _credencialesGuardadas = false;
  bool _certificadoGuardado = false;
  String _envioBoletas = 'individual';
  String _entorno = _entornoBeta;
  String? _nombreArchivo;
  Uint8List? _bytesCertificado;
  String? _error;

  OnboardingRepository get _repositorio =>
      ref.read(onboardingRepositoryProvider);

  bool get _puedeProduccion =>
      _credencialesGuardadas &&
      _certificadoGuardado &&
      _ruc.text.trim() != empresaDePruebaInicial['ruc'];

  @override
  void dispose() {
    for (final controlador in [
      _nombreComercial,
      _telefono,
      _correo,
      _nombreLocal,
      _ruc,
      _razonSocial,
      _direccion,
      _ubigeo,
      _departamento,
      _provincia,
      _distrito,
      _usuarioSol,
      _claveSol,
      _claveCertificado,
      _confirmarRuc,
    ]) {
      controlador.dispose();
    }
    super.dispose();
  }

  Future<void> _buscarRuc() async {
    final problema = validarRuc(_ruc.text);
    if (problema != null) {
      setState(() => _error = problema);
      return;
    }
    setState(() {
      _buscandoRuc = true;
      _error = null;
    });
    try {
      final datos = await _repositorio.consultarRuc(_ruc.text.trim());
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
      if (mounted) setState(() => _buscandoRuc = false);
    }
  }

  Map<String, dynamic> _datosEmpresa() => {
    'ruc': _ruc.text.trim(),
    'razon_social': _razonSocial.text.trim(),
    'nombre_comercial': _nombreComercial.text.trim(),
    'ubigeo': _ubigeo.text.trim(),
    'departamento': _departamento.text.trim(),
    'provincia': _provincia.text.trim(),
    'distrito': _distrito.text.trim(),
    'direccion': _direccion.text.trim(),
    'telefono': _telefono.text.trim(),
    'correo': _correo.text.trim(),
  };

  Future<void> _guardarEmpresa() async {
    if (_empresaGuardada) {
      await _repositorio.actualizarEmpresa(_datosEmpresa());
      return;
    }
    await _repositorio.guardarConfiguracionInicial(
      empresa: _datosEmpresa(),
      establecimiento: {
        'codigo': '0000',
        'nombre': _nombreLocal.text.trim(),
        'direccion': _direccion.text.trim(),
        'ubigeo': _ubigeo.text.trim(),
      },
    );
    _empresaGuardada = true;
  }

  Future<void> _guardarCredenciales() async {
    await _repositorio.guardarCredenciales(
      usuarioSol: _usuarioSol.text.trim(),
      claveSol: _claveSol.text,
      envioBoletas: _envioBoletas,
    );
    _credencialesGuardadas = true;
    _claveSol.clear();
  }

  Future<void> _guardarCertificado() async {
    final bytes = _bytesCertificado;
    if (bytes == null) {
      throw const ApiException(
        'SIN_ARCHIVO',
        'Elige el archivo del certificado.',
      );
    }
    await _repositorio.subirCertificado(
      bytes: bytes,
      nombreArchivo: _nombreArchivo!,
      clave: _claveCertificado.text,
    );
    _certificadoGuardado = true;
    _claveCertificado.clear();
  }

  Future<void> _finalizar() async {
    await _repositorio.definirEntorno(
      entorno: _entorno,
      confirmarRuc: _entorno == _entornoProduccion
          ? _confirmarRuc.text.trim()
          : _ruc.text.trim(),
    );
    ref.invalidate(empresaActualProvider);
    final empresa = await ref.read(empresaActualProvider.future);
    if (empresa?.configurada != true) {
      throw const ApiException(
        'CONFIGURACION_INCOMPLETA',
        'La empresa aún no figura como configurada. Inténtalo de nuevo.',
      );
    }
    if (mounted) context.go(inicioPorRol(ref.read(rolActualProvider)));
  }

  Future<void> _continuar() async {
    if (!_formularios[_paso].currentState!.validate()) return;
    final accion = switch (_paso) {
      0 => null,
      1 => _guardarEmpresa,
      2 => _guardarCredenciales,
      3 => _guardarCertificado,
      _ => _finalizar,
    };
    if (accion == null) {
      setState(() {
        _error = null;
        _paso++;
      });
      return;
    }
    setState(() {
      _trabajando = true;
      _error = null;
    });
    try {
      await accion();
      if (mounted && _paso < _titulosPasos.length - 1) {
        setState(() => _paso++);
      }
    } catch (error) {
      if (mounted) setState(() => _error = mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  Future<void> _omitirYProbar() async {
    setState(() {
      _trabajando = true;
      _error = null;
    });
    try {
      await _repositorio.guardarConfiguracionInicial(
        empresa: empresaDePruebaInicial,
        establecimiento: establecimientoDePruebaInicial,
      );
      ref.invalidate(empresaActualProvider);
      await ref.read(empresaActualProvider.future);
      if (mounted) context.go(Rutas.pos);
    } catch (error) {
      if (mounted) setState(() => _error = mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _trabajando = false);
    }
  }

  void _omitir() => setState(() {
    _error = null;
    _paso++;
  });

  void _volver() => setState(() {
    _error = null;
    _paso--;
  });

  Future<void> _elegirCertificado() async {
    final archivo = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pfx', 'p12', 'pem'],
    );
    if (archivo == null) return;
    final bytes = await archivo.readAsBytes();
    if (!mounted) return;
    setState(() {
      _nombreArchivo = archivo.name;
      _bytesCertificado = bytes;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final esOpcional = _paso == 2 || _paso == 3;
    final esUltimo = _paso == _titulosPasos.length - 1;
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Configura tu empresa',
            automaticBack: false,
            actions: [
              AppHeaderAction(
                icon: LucideIcons.logOut,
                tooltip: 'Salir',
                label: 'Salir',
                onPressed: ref.read(controladorSesionProvider).cerrarSesion,
              ),
            ],
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    children: [
                      _Progreso(paso: _paso),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formularios[_paso],
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_paso == 0 && !_empresaGuardada) ...[
                                  _TarjetaOmitir(
                                    cargando: _trabajando,
                                    alTocar: _omitirYProbar,
                                  ),
                                  const SizedBox(height: AppSpace.x4),
                                ],
                                Text(
                                  _titulosPasos[_paso],
                                  style: context.textos.headlineSmall,
                                ),
                                const SizedBox(height: 16),
                                _contenidoPaso(),
                                if (_error != null) ...[
                                  const SizedBox(height: 14),
                                  Text(
                                    _error!,
                                    style: context.textos.bodyMedium?.copyWith(
                                      color: context.colores.error,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: Column(
                          children: [
                            BotonPrimario(
                              texto: esUltimo
                                  ? 'Empezar a vender'
                                  : 'Continuar',
                              cargando: _trabajando,
                              onPressed: _continuar,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (_paso > 0)
                                  TextButton(
                                    onPressed: _trabajando ? null : _volver,
                                    child: const Text('Volver'),
                                  )
                                else
                                  const SizedBox.shrink(),
                                if (esOpcional)
                                  TextButton(
                                    onPressed: _trabajando ? null : _omitir,
                                    child: const Text('Configurar después'),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contenidoPaso() => switch (_paso) {
    0 => _pasoNegocio(),
    1 => _pasoRuc(),
    2 => _pasoSol(),
    3 => _pasoCertificado(),
    _ => _pasoEntorno(),
  };

  Widget _separados(List<Widget> campos) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < campos.length; i++) ...[
        if (i > 0) const SizedBox(height: 14),
        campos[i],
      ],
    ],
  );

  Widget _pasoNegocio() => _separados([
    CampoTexto(
      etiqueta: 'Nombre comercial',
      controller: _nombreComercial,
      capitalizacion: TextCapitalization.words,
      ayuda: 'El nombre que tus clientes ven en el ticket.',
      validator: validarRequerido,
    ),
    CampoTexto(
      etiqueta: 'Teléfono',
      controller: _telefono,
      teclado: TextInputType.phone,
    ),
    CampoTexto(
      etiqueta: 'Correo de la empresa',
      controller: _correo,
      teclado: TextInputType.emailAddress,
      validator: validarCorreoOpcional,
    ),
    CampoTexto(
      etiqueta: 'Nombre del local principal',
      controller: _nombreLocal,
      capitalizacion: TextCapitalization.words,
      validator: validarRequerido,
    ),
  ]);

  Widget _pasoRuc() => _separados([
    CampoTexto(
      etiqueta: 'RUC',
      controller: _ruc,
      teclado: TextInputType.number,
      longitudMaxima: 11,
      formateadores: [FilteringTextInputFormatter.digitsOnly],
      validator: validarRuc,
      sufijo: _buscandoRuc
          ? const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          : IconButton(
              tooltip: 'Buscar RUC',
              icon: const Icon(LucideIcons.search),
              onPressed: _buscarRuc,
            ),
      onSubmitted: (_) => _buscarRuc(),
    ),
    CampoTexto(
      etiqueta: 'Razón social',
      controller: _razonSocial,
      validator: validarRequerido,
    ),
    CampoTexto(
      etiqueta: 'Dirección fiscal',
      controller: _direccion,
      validator: validarRequerido,
    ),
    CampoTexto(
      etiqueta: 'Ubigeo',
      controller: _ubigeo,
      teclado: TextInputType.number,
      longitudMaxima: 6,
      formateadores: [FilteringTextInputFormatter.digitsOnly],
      validator: validarUbigeo,
    ),
    CampoTexto(
      etiqueta: 'Departamento',
      controller: _departamento,
      validator: validarRequerido,
    ),
    CampoTexto(
      etiqueta: 'Provincia',
      controller: _provincia,
      validator: validarRequerido,
    ),
    CampoTexto(
      etiqueta: 'Distrito',
      controller: _distrito,
      validator: validarRequerido,
    ),
  ]);

  Widget _pasoSol() => _separados([
    Text(
      'Son los datos con los que entras a SUNAT Operaciones en Línea. '
      'Se guardan cifrados y no se vuelven a mostrar.',
      style: context.textos.bodyMedium,
    ),
    CampoTexto(
      etiqueta: 'Usuario SOL',
      controller: _usuarioSol,
      validator: validarRequerido,
    ),
    CampoTexto(
      etiqueta: 'Clave SOL',
      controller: _claveSol,
      esClave: true,
      validator: validarRequerido,
    ),
    AppSelectorField<String>(
      titulo: 'Envío de boletas',
      icono: LucideIcons.send,
      initialValue: _envioBoletas,
      etiqueta: 'Envío de boletas',
      opciones: const [
        AppSelectorOption(value: 'individual', label: 'Una por una'),
        AppSelectorOption(value: 'resumen_diario', label: 'Resumen diario'),
      ],
      onChanged: (valor) => setState(() => _envioBoletas = valor!),
    ),
  ]);

  Widget _pasoCertificado() => _separados([
    Text(
      'Sube tu certificado .pfx, .p12 o .pem. Comprobamos que corresponda a '
      'tu RUC y que esté vigente.',
      style: context.textos.bodyMedium,
    ),
    BotonSecundario(
      texto: _nombreArchivo ?? 'Elegir archivo',
      icono: LucideIcons.fileUp,
      onPressed: _elegirCertificado,
    ),
    CampoTexto(
      etiqueta: 'Contraseña del certificado',
      controller: _claveCertificado,
      esClave: true,
      validator: validarRequerido,
    ),
  ]);

  Widget _pasoEntorno() => _separados([
    SelectableCard(
      leading: const IconChip(LucideIcons.flaskConical),
      title: 'Pruebas',
      subtitle: 'Los comprobantes no tienen valor tributario.',
      selected: _entorno == _entornoBeta,
      onTap: () => setState(() => _entorno = _entornoBeta),
    ),
    SelectableCard(
      leading: const IconChip(LucideIcons.badgeCheck),
      title: 'Producción',
      subtitle: _puedeProduccion
          ? 'Los comprobantes se envían a SUNAT con valor tributario.'
          : 'Necesitas tu RUC real, usuario SOL y certificado.',
      selected: _entorno == _entornoProduccion,
      enabled: _puedeProduccion,
      onTap: () => setState(() => _entorno = _entornoProduccion),
    ),
    if (_entorno == _entornoProduccion)
      CampoTexto(
        etiqueta: 'Escribe tu RUC para confirmar',
        controller: _confirmarRuc,
        teclado: TextInputType.number,
        longitudMaxima: 11,
        formateadores: [FilteringTextInputFormatter.digitsOnly],
        validator: (valor) =>
            valor?.trim() == _ruc.text.trim() ? null : 'El RUC no coincide',
      ),
  ]);
}

class _TarjetaOmitir extends StatelessWidget {
  const _TarjetaOmitir({required this.cargando, required this.alTocar});

  final bool cargando;
  final VoidCallback alTocar;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpace.x4),
      decoration: BoxDecoration(
        color: p.brandSoft,
        borderRadius: BorderRadius.circular(AppV2.cardRadius),
        border: Border.all(color: p.brand.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconChip(LucideIcons.rocket),
              const SizedBox(width: AppSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¿Solo quieres probar?', style: t.titleSmall),
                    Text(
                      'Empieza con datos de prueba. Tus datos reales se piden '
                      'recién al pasar a producción.',
                      style: t.bodySmall?.copyWith(color: p.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.x3),
          AppButton(
            label: 'Omitir y probar la app',
            icon: LucideIcons.play,
            size: AppButtonSize.large,
            expand: true,
            loading: cargando,
            onPressed: alTocar,
          ),
        ],
      ),
    );
  }
}

class _Progreso extends StatelessWidget {
  const _Progreso({required this.paso});

  final int paso;

  @override
  Widget build(BuildContext context) {
    final colores = context.colores;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Semantics(
        label: 'Paso ${paso + 1} de ${_titulosPasos.length}',
        child: Row(
          children: [
            for (var i = 0; i < _titulosPasos.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: i <= paso ? colores.primary : colores.outlineVariant,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
