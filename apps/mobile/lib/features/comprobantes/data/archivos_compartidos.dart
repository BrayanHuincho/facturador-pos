import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Rect? origenCompartir(BuildContext context) {
  final caja = context.findRenderObject();
  if (caja is! RenderBox || !caja.hasSize) return null;
  return caja.localToGlobal(Offset.zero) & caja.size;
}

Future<void> _compartirArchivo(
  File archivo,
  String titulo,
  Rect? origen,
) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile(archivo.path)],
      subject: titulo,
      sharePositionOrigin: origen,
    ),
  );
}

Future<File> _archivoTemporal(String nombre) async {
  final directorio = await getTemporaryDirectory();
  return File('${directorio.path}${Platform.pathSeparator}$nombre');
}

Future<void> compartirDesdeUrl({
  required String url,
  required String nombre,
  required String titulo,
  Rect? origen,
}) async {
  final respuesta = await Dio().get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
  );
  final archivo = await _archivoTemporal(nombre);
  await archivo.writeAsBytes(respuesta.data ?? const [], flush: true);
  await _compartirArchivo(archivo, titulo, origen);
}

Future<void> compartirTexto({
  required String contenido,
  required String nombre,
  required String titulo,
  Rect? origen,
}) async {
  final archivo = await _archivoTemporal(nombre);
  await archivo.writeAsString(contenido, encoding: utf8, flush: true);
  await _compartirArchivo(archivo, titulo, origen);
}
