import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/widgets.dart';
import '../data/impresoras.dart';
import '../domain/impresora.dart';
import 'impresion_providers.dart';

class ImpresoraScreen extends ConsumerStatefulWidget {
  const ImpresoraScreen({super.key});

  @override
  ConsumerState<ImpresoraScreen> createState() => _ImpresoraScreenState();
}

class _ImpresoraScreenState extends ConsumerState<ImpresoraScreen> {
  final _ip = TextEditingController();
  final _puerto = TextEditingController();
  ConfigImpresora? _config;
  List<DispositivoBluetooth> _dispositivos = const [];
  bool _buscando = false;
  bool _probando = false;
  String? _errorBusqueda;

  @override
  void initState() {
    super.initState();
    ref.read(configImpresoraProvider.future).then((config) {
      if (!mounted) return;
      setState(() {
        _config = config;
        _ip.text = config.ip;
        _puerto.text = '${config.puerto}';
      });
      if (config.conexion == ConexionImpresora.bluetooth) _buscar();
    });
  }

  @override
  void dispose() {
    _ip.dispose();
    _puerto.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    setState(() {
      _buscando = true;
      _errorBusqueda = null;
    });
    try {
      final lista = await dispositivosEmparejados();
      if (mounted) setState(() => _dispositivos = lista);
    } on FalloImpresora catch (e) {
      if (mounted) setState(() => _errorBusqueda = e.mensaje);
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _actualizar(ConfigImpresora nueva) {
    setState(() => _config = nueva);
    ref.read(configImpresoraProvider.notifier).guardar(nueva);
  }

  void _actualizarRed() {
    final actual = _config;
    if (actual == null) return;
    _actualizar(
      actual.copiar(
        ip: _ip.text.trim(),
        puerto:
            int.tryParse(_puerto.text.trim()) ??
            ConfigImpresora.puertoPorDefecto,
      ),
    );
  }

  Future<void> _probar() async {
    final config = _config;
    if (config == null) return;
    setState(() => _probando = true);
    final mensajero = ScaffoldMessenger.of(context);
    try {
      await ref.read(impresionServiceProvider).imprimirPrueba(config);
      mensajero.showSnackBar(const SnackBar(content: Text('Prueba enviada.')));
    } on FalloImpresora catch (e) {
      mensajero.showSnackBar(SnackBar(content: Text(e.mensaje)));
    } finally {
      if (mounted) setState(() => _probando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final p = context.palette;
    return Scaffold(
      body: Column(
        children: [
          const AppHeader(title: 'Impresora'),
          Expanded(
            child: config == null
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpace.x4),
                        children: [
                          SectionCard(
                            title: 'Conexión',
                            child: SegmentedButton<ConexionImpresora>(
                              segments: [
                                for (final c in ConexionImpresora.values)
                                  ButtonSegment(
                                    value: c,
                                    label: Text(c.etiqueta),
                                  ),
                              ],
                              selected: {config.conexion},
                              onSelectionChanged: (s) {
                                _actualizar(config.copiar(conexion: s.first));
                                if (s.first == ConexionImpresora.bluetooth) {
                                  _buscar();
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: AppSpace.x3),
                          SectionCard(
                            title: 'Papel',
                            child: SegmentedButton<PapelImpresora>(
                              segments: [
                                for (final papel in PapelImpresora.values)
                                  ButtonSegment(
                                    value: papel,
                                    label: Text(papel.etiqueta),
                                  ),
                              ],
                              selected: {config.papel},
                              onSelectionChanged: (s) =>
                                  _actualizar(config.copiar(papel: s.first)),
                            ),
                          ),
                          const SizedBox(height: AppSpace.x3),
                          if (config.conexion == ConexionImpresora.red)
                            SectionCard(
                              title: 'Red',
                              child: Column(children: _camposRed()),
                            )
                          else
                            ..._listaBluetooth(config),
                          const SizedBox(height: AppSpace.x3),
                          SectionCard(
                            title: 'Impresión',
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Imprimir al emitir'),
                              value: config.imprimirAlEmitir,
                              onChanged: (v) => _actualizar(
                                config.copiar(imprimirAlEmitir: v),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          if (config != null)
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
                    texto: _probando ? 'Enviando...' : 'Imprimir prueba',
                    icono: LucideIcons.printer,
                    onPressed: config.configurada && !_probando
                        ? _probar
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _camposRed() => [
    CampoTexto(
      etiqueta: 'Dirección IP',
      controller: _ip,
      teclado: TextInputType.url,
      onChanged: (_) => _actualizarRed(),
    ),
    const SizedBox(height: AppSpace.x3),
    CampoTexto(
      etiqueta: 'Puerto',
      controller: _puerto,
      teclado: TextInputType.number,
      onChanged: (_) => _actualizarRed(),
    ),
  ];

  List<Widget> _listaBluetooth(ConfigImpresora config) {
    final paleta = context.palette;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              'Dispositivos emparejados',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _buscando ? null : _buscar,
            icon: const Icon(LucideIcons.refreshCw),
          ),
        ],
      ),
      if (_buscando) const LinearProgressIndicator(),
      if (_errorBusqueda != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
          child: Text(_errorBusqueda!, style: TextStyle(color: paleta.danger)),
        ),
      if (!_buscando && _errorBusqueda == null && _dispositivos.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.x2),
          child: Text(
            'Empareja la impresora desde los ajustes del teléfono.',
            style: TextStyle(color: paleta.textMuted),
          ),
        ),
      const SizedBox(height: AppSpace.x2),
      for (final d in _dispositivos)
        ListCard(
          margin: const EdgeInsets.only(bottom: AppSpace.x2 + 2),
          leading: const IconChip(LucideIcons.printer),
          title: d.nombre,
          subtitle: d.direccion,
          trailing: Icon(
            d.direccion == config.direccionBluetooth
                ? LucideIcons.circleDot
                : LucideIcons.circle,
            color: d.direccion == config.direccionBluetooth
                ? paleta.brand
                : paleta.textMuted,
          ),
          onTap: () => _actualizar(
            config.copiar(
              nombreBluetooth: d.nombre,
              direccionBluetooth: d.direccion,
            ),
          ),
        ),
    ];
  }
}
