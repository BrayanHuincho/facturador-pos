import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/api_client.dart';
import '../../../core/formatos/validadores.dart';
import '../../../core/sesion/sesion_providers.dart';
import '../../../core/widgets/widgets.dart';
import '../data/catalogo_repository.dart';
import '../domain/catalogo_models.dart';

class ClientesScreen extends ConsumerStatefulWidget {
  const ClientesScreen({super.key});

  @override
  ConsumerState<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends ConsumerState<ClientesScreen> {
  static const _esperaBusqueda = Duration(milliseconds: 300);

  Timer? _temporizador;
  String _termino = '';

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  void _alBuscar(String texto) {
    _temporizador?.cancel();
    _temporizador = Timer(_esperaBusqueda, () {
      if (mounted) setState(() => _termino = texto.trim());
    });
  }

  Future<void> _abrirFormulario({Cliente? cliente}) =>
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        builder: (_) => _FormularioCliente(cliente: cliente),
      );

  @override
  Widget build(BuildContext context) {
    final rol = ref.watch(rolActualProvider);
    final puedeEditar = rol == RolUsuario.admin || rol == RolUsuario.cajero;
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: 'Clientes',
            actions: [
              if (puedeEditar)
                AppHeaderAction(
                  icon: LucideIcons.userPlus,
                  tooltip: 'Nuevo cliente',
                  label: 'Crear',
                  onPressed: _abrirFormulario,
                ),
            ],
            bottom: AppSearchField.onBrand(
              hint: 'Buscar por nombre o documento',
              onChanged: _alBuscar,
            ),
          ),
          Expanded(
            child: ContenidoAsync<List<Cliente>>(
              valor: ref.watch(clientesProvider(_termino)),
              onReintentar: () => ref.invalidate(clientesProvider),
              builder: (filas) {
                final visibles = rol == RolUsuario.admin
                    ? filas
                    : filas.where((c) => c.activo).toList();
                if (visibles.isEmpty) {
                  return const EstadoVacio(titulo: 'Sin clientes');
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.x4,
                    AppSpace.x3,
                    AppSpace.x4,
                    AppSpace.x6,
                  ),
                  itemCount: visibles.length,
                  itemBuilder: (_, indice) {
                    final cliente = visibles[indice];
                    final tipo =
                        tiposDocumentoCliente[cliente.tipoDocumento] ??
                        cliente.tipoDocumento;
                    return ListCard(
                      margin: const EdgeInsets.only(bottom: AppSpace.x2 + 2),
                      dimmed: !cliente.activo,
                      leading: const IconChip(LucideIcons.user),
                      title: cliente.nombre,
                      subtitle:
                          '$tipo ${cliente.numeroDocumento}${cliente.activo ? '' : ' · Inactivo'}',
                      onTap: puedeEditar
                          ? () => _abrirFormulario(cliente: cliente)
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FormularioCliente extends ConsumerStatefulWidget {
  const _FormularioCliente({this.cliente});

  final Cliente? cliente;

  @override
  ConsumerState<_FormularioCliente> createState() => _FormularioClienteState();
}

class _FormularioClienteState extends ConsumerState<_FormularioCliente> {
  final _formulario = GlobalKey<FormState>();
  late final _numero = TextEditingController(
    text: widget.cliente?.numeroDocumento,
  );
  late final _nombre = TextEditingController(text: widget.cliente?.nombre);
  late final _direccion = TextEditingController(
    text: widget.cliente?.direccion,
  );
  late final _telefono = TextEditingController(text: widget.cliente?.telefono);
  late final _correo = TextEditingController(text: widget.cliente?.correo);
  late String? _ubigeo = widget.cliente?.ubigeo;
  late String _tipo = widget.cliente?.tipoDocumento ?? tipoDocumentoDni;
  late bool _activo = widget.cliente?.activo ?? true;
  bool _guardando = false;
  bool _consultando = false;

  bool get _admiteConsulta =>
      _tipo == tipoDocumentoDni || _tipo == tipoDocumentoRuc;
  bool get _sinDocumento => _tipo == tipoDocumentoSinDocumento;

  @override
  void dispose() {
    _numero.dispose();
    _nombre.dispose();
    _direccion.dispose();
    _telefono.dispose();
    _correo.dispose();
    super.dispose();
  }

  String? _validarNumero(String? valor) {
    if (_sinDocumento) return null;
    return switch (_tipo) {
      tipoDocumentoDni => validarDni(valor),
      tipoDocumentoRuc => validarRuc(valor),
      _ => validarRequerido(valor, mensaje: 'Escribe el número de documento'),
    };
  }

  String? _textoONulo(TextEditingController controlador) {
    final texto = controlador.text.trim();
    return texto.isEmpty ? null : texto;
  }

  void _cambiarTipo(String? tipo) {
    if (tipo == null) return;
    setState(() {
      _tipo = tipo;
      _numero.text = tipo == tipoDocumentoSinDocumento
          ? numeroSinDocumento
          : '';
    });
  }

  Future<void> _consultar() async {
    final numero = _numero.text.trim();
    final problema = _validarNumero(numero);
    if (problema != null) {
      mostrarMensaje(context, problema, error: true);
      return;
    }
    setState(() => _consultando = true);
    try {
      final datos = await ref
          .read(catalogoRepositoryProvider)
          .consultarDocumento(_tipo, numero);
      if (!mounted) return;
      setState(() {
        _nombre.text = datos.nombre;
        if (datos.direccion != null) _direccion.text = datos.direccion!;
        _ubigeo = datos.ubigeo ?? _ubigeo;
      });
    } catch (error) {
      if (mounted) mostrarMensaje(context, mensajeDeError(error), error: true);
    } finally {
      if (mounted) setState(() => _consultando = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      await ref.read(catalogoRepositoryProvider).guardarCliente(
        widget.cliente?.id,
        {
          'tipo_documento': _tipo,
          'numero_documento': _numero.text.trim(),
          'nombre': _nombre.text.trim(),
          'direccion': _textoONulo(_direccion),
          'ubigeo': _ubigeo,
          'telefono': _textoONulo(_telefono),
          'correo': _textoONulo(_correo),
          'activo': _activo,
        },
      );
      ref.invalidate(clientesProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        mostrarMensaje(context, mensajeDeEscritura(error), error: true);
        setState(() => _guardando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final esAdmin = ref.watch(rolActualProvider) == RolUsuario.admin;
    const separacion = SizedBox(height: AppSpace.x3);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Form(
          key: _formulario,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpace.x4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.cliente == null ? 'Nuevo cliente' : 'Editar cliente',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: AppSpace.x4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Documento',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: context.palette.text),
                  ),
                ),
                const SizedBox(height: AppSpace.x1 + 2),
                AppSelectorField<String>(
                  titulo: 'Tipo de documento',
                  icono: LucideIcons.idCard,
                  initialValue: _tipo,
                  opciones: [
                    for (final tipo in tiposDocumentoCliente.entries)
                      AppSelectorOption(value: tipo.key, label: tipo.value),
                  ],
                  onChanged: _cambiarTipo,
                ),
                separacion,
                CampoTexto(
                  etiqueta: 'Número',
                  controller: _numero,
                  habilitado: !_sinDocumento,
                  teclado: _admiteConsulta ? TextInputType.number : null,
                  longitudMaxima: 15,
                  validator: _validarNumero,
                  sufijo: _admiteConsulta
                      ? IconButton(
                          tooltip: 'Consultar',
                          icon: _consultando
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(LucideIcons.search),
                          onPressed: _consultando ? null : _consultar,
                        )
                      : null,
                ),
                separacion,
                CampoTexto(
                  etiqueta: 'Nombre o razón social',
                  controller: _nombre,
                  validator: validarRequerido,
                ),
                separacion,
                CampoTexto(etiqueta: 'Dirección', controller: _direccion),
                separacion,
                CampoTexto(
                  etiqueta: 'Teléfono',
                  controller: _telefono,
                  teclado: TextInputType.phone,
                ),
                separacion,
                CampoTexto(
                  etiqueta: 'Correo',
                  controller: _correo,
                  teclado: TextInputType.emailAddress,
                  validator: validarCorreoOpcional,
                ),
                if (esAdmin && widget.cliente != null)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cliente activo'),
                    value: _activo,
                    onChanged: (valor) => setState(() => _activo = valor),
                  ),
                const SizedBox(height: AppSpace.x4),
                BotonPrimario(
                  texto: 'Guardar',
                  cargando: _guardando,
                  onPressed: _guardar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
