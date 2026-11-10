import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errores/errores.dart';
import '../../../core/formatos/validadores.dart';
import '../../../core/router/rutas.dart';
import '../../../core/sesion/sesion_providers.dart';
import '../../../core/widgets/widgets.dart';
import 'marco_acceso.dart';

class RecuperarClavePage extends ConsumerStatefulWidget {
  const RecuperarClavePage({super.key});

  @override
  ConsumerState<RecuperarClavePage> createState() => _RecuperarClaveState();
}

class _RecuperarClaveState extends ConsumerState<RecuperarClavePage> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _codigo = TextEditingController();
  final _clave = TextEditingController();
  bool _codigoEnviado = false;
  bool _enviando = false;
  String? _error;

  @override
  void dispose() {
    _correo.dispose();
    _codigo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _ejecutar(Future<void> Function() accion) async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await accion();
    } catch (error) {
      if (mounted) setState(() => _error = mensajeDeError(error));
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _enviarCodigo() async {
    await ref
        .read(controladorSesionProvider)
        .enviarCodigoRecuperacion(_correo.text);
    if (mounted) setState(() => _codigoEnviado = true);
  }

  Future<void> _restablecer() async {
    await ref
        .read(controladorSesionProvider)
        .restablecerClave(
          correo: _correo.text,
          codigo: _codigo.text,
          claveNueva: _clave.text,
        );
    if (!mounted) return;
    mostrarMensaje(context, 'Contraseña actualizada. Ya puedes entrar.');
    context.go(Rutas.login);
  }

  @override
  Widget build(BuildContext context) {
    return MarcoAcceso(
      alVolver: () => context.go(Rutas.login),
      child: Form(
        key: _formulario,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AccesoEncabezado(
              titulo: 'Recupera tu contraseña',
              bajada: _codigoEnviado
                  ? 'Escribe el código que enviamos a tu correo y elige una contraseña nueva.'
                  : 'Te enviaremos un código a tu correo para crear una contraseña nueva.',
            ),
            const SizedBox(height: 20),
            CampoTexto(
              etiqueta: 'Correo',
              controller: _correo,
              validator: validarCorreo,
              teclado: TextInputType.emailAddress,
              soloLectura: _codigoEnviado,
            ),
            if (_codigoEnviado) ...[
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Código',
                controller: _codigo,
                teclado: TextInputType.number,
                formateadores: [FilteringTextInputFormatter.digitsOnly],
                validator: (valor) =>
                    validarRequerido(valor, mensaje: 'Escribe el código'),
              ),
              const SizedBox(height: 14),
              CampoTexto(
                etiqueta: 'Contraseña nueva',
                controller: _clave,
                esClave: true,
                validator: validarClaveNueva,
                autofill: const [AutofillHints.newPassword],
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              AvisoAcceso(mensaje: _error!),
            ],
            const SizedBox(height: 20),
            BotonPrimario(
              texto: _codigoEnviado ? 'Cambiar contraseña' : 'Enviar código',
              cargando: _enviando,
              onPressed: () =>
                  _ejecutar(_codigoEnviado ? _restablecer : _enviarCodigo),
            ),
          ],
        ),
      ),
    );
  }
}
