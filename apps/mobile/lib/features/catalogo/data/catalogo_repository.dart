import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/api_client.dart';
import '../../../core/formatos/formatos.dart';
import '../../../core/sesion/sesion_providers.dart';
import '../domain/catalogo_models.dart';

const int limiteResultadosCatalogo = 200;
const String _bucketImagenes = 'imagenes';
const String _violacionUnicidad = '23505';
const String _permisoDenegado = '42501';

final catalogoRepositoryProvider = Provider<CatalogoAdminRepository>(
  (ref) => CatalogoAdminRepository(
    ref.watch(apiClientProvider),
    ref.watch(supabaseProvider),
  ),
);

final productosProvider = FutureProvider.autoDispose
    .family<List<Producto>, String>(
      (ref, termino) =>
          ref.watch(catalogoRepositoryProvider).listarProductos(termino),
    );

final productoProvider = FutureProvider.autoDispose.family<Producto, String>(
  (ref, id) => ref.watch(catalogoRepositoryProvider).obtenerProducto(id),
);

final categoriasProvider = FutureProvider.autoDispose<List<Categoria>>(
  (ref) => ref.watch(catalogoRepositoryProvider).listarCategorias(),
);

final stockProductoProvider = FutureProvider.autoDispose
    .family<List<StockLocal>, String>(
      (ref, productoId) =>
          ref.watch(catalogoRepositoryProvider).listarStock(productoId),
    );

final clientesProvider = FutureProvider.autoDispose
    .family<List<Cliente>, String>(
      (ref, termino) =>
          ref.watch(catalogoRepositoryProvider).listarClientes(termino),
    );

String mensajeDeEscritura(Object error) {
  if (error is PostgrestException) {
    return switch (error.code) {
      _violacionUnicidad => 'Ya existe un registro con esos datos.',
      _permisoDenegado => 'No tienes permiso para realizar esta acción.',
      _ => 'No se pudo guardar. Inténtalo de nuevo.',
    };
  }
  if (error is StorageException) return 'No se pudo subir la imagen.';
  return mensajeDeError(error);
}

String _terminoSeguro(String termino) =>
    '"%${termino.replaceAll(r'\', '').replaceAll('"', '')}%"';

class CatalogoAdminRepository {
  CatalogoAdminRepository(this._api, this._supabase);

  final ApiClient _api;
  final SupabaseClient _supabase;

  Future<List<Producto>> listarProductos(String termino) async {
    final filtro = _supabase.from('productos').select();
    final limpio = termino.trim();
    final filas =
        await (limpio.isEmpty
                ? filtro
                : filtro.or(
                    'nombre.ilike.${_terminoSeguro(limpio)},'
                    'codigo.ilike.${_terminoSeguro(limpio)},'
                    'codigo_barras.ilike.${_terminoSeguro(limpio)}',
                  ))
            .order('nombre')
            .limit(limiteResultadosCatalogo);
    return filas.map(Producto.desdeJson).toList();
  }

  Future<Producto> obtenerProducto(String id) async => Producto.desdeJson(
    await _supabase.from('productos').select().eq('id', id).single(),
  );

  Future<String> guardarProducto(String? id, Map<String, dynamic> datos) async {
    final tabla = _supabase.from('productos');
    final fila =
        await (id == null
                ? tabla.insert(datos)
                : tabla.update(datos).eq('id', id))
            .select('id')
            .single();
    return fila['id'] as String;
  }

  Future<void> cambiarProductoActivo(String id, bool activo) =>
      _supabase.from('productos').update({'activo': activo}).eq('id', id);

  Future<String> subirImagenProducto({
    required Uint8List contenido,
    required String nombreArchivo,
  }) async {
    final nombre = nombreArchivo.toLowerCase();
    final extension = nombre.contains('.') ? nombre.split('.').last : 'jpg';
    final tipo = switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final ruta =
        'productos/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _supabase.storage
        .from(_bucketImagenes)
        .uploadBinary(
          ruta,
          contenido,
          fileOptions: FileOptions(contentType: tipo, upsert: true),
        );
    return ruta;
  }

  String urlImagen(String ruta) =>
      _supabase.storage.from(_bucketImagenes).getPublicUrl(ruta);

  Future<List<Categoria>> listarCategorias() async {
    final filas = await _supabase
        .from('categorias')
        .select()
        .order('orden')
        .order('nombre');
    return filas.map(Categoria.desdeJson).toList();
  }

  Future<void> guardarCategoria(
    String? id, {
    required String nombre,
    required int orden,
  }) async {
    final datos = {'nombre': nombre, 'orden': orden};
    final tabla = _supabase.from('categorias');
    await (id == null ? tabla.insert(datos) : tabla.update(datos).eq('id', id));
  }

  Future<void> cambiarCategoriaActiva(String id, bool activa) =>
      _supabase.from('categorias').update({'activa': activa}).eq('id', id);

  Future<List<StockLocal>> listarStock(String productoId) async {
    final resultados = await Future.wait([
      _supabase
          .from('establecimientos')
          .select('id, nombre')
          .eq('activo', true)
          .order('codigo'),
      _supabase
          .from('stock')
          .select('establecimiento_id, cantidad')
          .eq('producto_id', productoId),
    ]);
    final cantidades = {
      for (final fila in resultados[1])
        fila['establecimiento_id'] as String: fila['cantidad'],
    };
    return [
      for (final local in resultados[0])
        StockLocal(
          establecimientoId: local['id'] as String,
          establecimientoNombre: local['nombre'] as String? ?? '',
          cantidad: parseDecimal(cantidades[local['id']]),
        ),
    ];
  }

  Future<void> ajustarStock({
    required String productoId,
    required String establecimientoId,
    required String cantidadConSigno,
    required String motivo,
  }) => _api.post<Map<String, dynamic>>(
    '/stock/ajustes',
    data: {
      'producto_id': productoId,
      'establecimiento_id': establecimientoId,
      'cantidad': cantidadConSigno,
      'motivo': motivo,
    },
  );

  Future<List<Cliente>> listarClientes(String termino) async {
    final filtro = _supabase.from('clientes').select();
    final limpio = termino.trim();
    final filas =
        await (limpio.isEmpty
                ? filtro
                : filtro.or(
                    'nombre.ilike.${_terminoSeguro(limpio)},'
                    'numero_documento.ilike.${_terminoSeguro(limpio)}',
                  ))
            .order('nombre')
            .limit(limiteResultadosCatalogo);
    return filas.map(Cliente.desdeJson).toList();
  }

  Future<void> guardarCliente(String? id, Map<String, dynamic> datos) async {
    final tabla = _supabase.from('clientes');
    await (id == null ? tabla.insert(datos) : tabla.update(datos).eq('id', id));
  }

  Future<void> cambiarClienteActivo(String id, bool activo) =>
      _supabase.from('clientes').update({'activo': activo}).eq('id', id);

  Future<DocumentoConsultado> consultarDocumento(
    String tipo,
    String numero,
  ) async => DocumentoConsultado.desdeJson(
    await _api.get<Map<String, dynamic>>('/consultas/documento/$tipo/$numero'),
  );
}
