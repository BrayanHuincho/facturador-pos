import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/widgets/visor_pdf.dart';
import '../../../design_system/design_system.dart';
import '../../impresion/domain/impresora.dart';
import '../../impresion/presentation/impresion_providers.dart';
import '../data/comprobantes_repository.dart';

Future<String> formatoPdfPredeterminado(WidgetRef ref) async {
  final config = await ref.read(configImpresoraProvider.future);
  return config.papel == PapelImpresora.mm58 ? 'pdf-ticket58' : 'pdf-ticket80';
}

Future<Uint8List> descargarPdf(String url) async {
  final respuesta = await Dio().get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
  );
  return Uint8List.fromList(respuesta.data ?? const []);
}

class DocumentoComprobante extends ConsumerStatefulWidget {
  const DocumentoComprobante({
    required this.comprobanteId,
    this.refresco,
    super.key,
  });

  final String comprobanteId;
  final Object? refresco;

  @override
  ConsumerState<DocumentoComprobante> createState() =>
      _DocumentoComprobanteState();
}

class _DocumentoComprobanteState extends ConsumerState<DocumentoComprobante> {
  Uint8List? _bytes;
  bool _fallo = false;
  int _turno = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(DocumentoComprobante anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.comprobanteId != widget.comprobanteId ||
        anterior.refresco != widget.refresco) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    final turno = ++_turno;
    try {
      final formato = await formatoPdfPredeterminado(ref);
      final url = await ref
          .read(comprobantesRepositoryProvider)
          .urlArchivo(widget.comprobanteId, formato);
      final bytes = await descargarPdf(url);
      if (!mounted || turno != _turno) return;
      setState(() {
        _bytes = bytes;
        _fallo = false;
      });
    } catch (_) {
      if (mounted && turno == _turno && _bytes == null) {
        setState(() => _fallo = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return VisorPdf(key: const ValueKey('documento-pdf'), bytes: bytes);
    }
    if (_fallo) {
      return EmptyState(
        icon: LucideIcons.receipt,
        title: 'Aún no se puede mostrar el documento',
        message: 'Inténtalo de nuevo en un momento.',
        actionLabel: 'Reintentar',
        onAction: () {
          setState(() => _fallo = false);
          _cargar();
        },
      );
    }
    return const CargandoDocumento();
  }
}
