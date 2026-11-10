import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errores/errores.dart';
import '../../../core/formatos/validadores.dart';
import '../../../core/router/rutas.dart';
import '../../../core/sesion/almacen_sesion_segura.dart';
import '../../../core/sesion/sesion_providers.dart';
import '../../../core/widgets/widgets.dart';
import 'marco_acceso.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _enviando = false;
  bool _recordar = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    AlmacenSesionSegura.instancia.correoRecordado().then((correo) {
      if (correo != null && mounted && _correo.text.isEmpty) {
        _correo.text = correo;
      }
    });
  }

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await ref
          .read(controladorSesionProvider)
          .iniciarSesion(_correo.text, _clave.text, recordar: _recordar);
    } catch (error) {
      if (mounted) setState(() => _error = mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MarcoAcceso(
      child: AutofillGroup(
        child: Form(
          key: _formulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const AccesoEncabezado(
                titulo: 'Inicia sesión',
                bajada: 'Ingresa a tu punto de venta.',
              ),
              const SizedBox(height: 20),
              CampoTexto(
                etiqueta: 'Correo',
                icono: LucideIcons.mail,
                controller: _correo,
                validator: validarCorreo,
                teclado: TextInputType.emailAddress,
                accionTeclado: TextInputAction.next,
                autofill: const [AutofillHints.email],
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Contraseña',
                icono: LucideIcons.lock,
                controller: _clave,
                esClave: true,
                validator: (valor) =>
                    validarRequerido(valor, mensaje: 'Escribe tu contraseña'),
                accionTeclado: TextInputAction.done,
                autofill: const [AutofillHints.password],
                onSubmitted: (_) => _entrar(),
              ),
              const SizedBox(height: 4),
              _Recordarme(
                valor: _recordar,
                alCambiar: (valor) => setState(() => _recordar = valor),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                AvisoAcceso(mensaje: _error!),
              ],
              const SizedBox(height: 12),
              BotonPrimario(
                texto: 'Entrar',
                icono: LucideIcons.logIn,
                cargando: _enviando,
                onPressed: _entrar,
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => context.push(Rutas.recuperarClave),
                child: const Text('Olvidé mi contraseña'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Recordarme extends StatelessWidget {
  const _Recordarme({required this.valor, required this.alCambiar});

  final bool valor;
  final ValueChanged<bool> alCambiar;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => alCambiar(!valor),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            SizedBox.square(
              dimension: 24,
              child: Checkbox(
                value: valor,
                onChanged: (v) => alCambiar(v ?? false),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Recordarme',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
