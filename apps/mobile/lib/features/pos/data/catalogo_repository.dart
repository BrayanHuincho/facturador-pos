import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/catalogo_pos.dart';
import '../domain/cobro.dart';

const _tamanoPagina = 1000;
const _claveCache = 'pos.catalogo';

class CatalogoRepository {
  CatalogoRepository(this._cliente);

  final SupabaseClient _cliente;

  Future<Catalogo> cargar() async {
    try {
      final catalogo = await _desdeServidor();
      await _guardarCache(catalogo);
      return catalogo;
    } catch (_) {
      final cache = await _leerCache();
      if (cache == null) rethrow;
      return cache;
    }
  }

  Future<Catalogo> _desdeServidor() async {
    final categorias = await _cliente
        .from('categorias')
        .select('id,nombre')
        .eq('activa', true)
        .order('orden');
    final empresa = await _cliente
        .from('empresa')
        .select('igv_porcentaje,precios_incluyen_igv')
        .eq('id', 1)
        .maybeSingle();
    final stock = await _stockDelEstablecimiento();
    final productos = <ProductoPos>[];
    for (var desde = 0; ; desde += _tamanoPagina) {
      final pagina = await _cliente
          .from('productos')
          .select(
            'id,nombre,precio,codigo,codigo_barras,categoria_id,unidad,'
            'afectacion,aplica_icbper,controla_stock,imagen_path',
          )
          .eq('activo', true)
          .order('nombre')
          .range(desde, desde + _tamanoPagina - 1);
      productos.addAll(
        pagina.map(
          (p) => ProductoPos.fromJson({...p, 'stock': stock[p['id']]}),
        ),
      );
      if (pagina.length < _tamanoPagina) break;
    }
    return Catalogo(
      categorias: categorias.map(CategoriaPos.fromJson).toList(),
      productos: productos,
      fiscal: empresa == null
          ? ConfiguracionFiscal.porDefecto()
          : ConfiguracionFiscal.fromJson(empresa),
    );
  }

  Future<Map<String, Object?>> _stockDelEstablecimiento() async {
    final usuario = _cliente.auth.currentUser;
    if (usuario == null) return const {};
    final perfil = await _cliente
        .from('perfiles')
        .select('establecimiento_id')
        .eq('id', usuario.id)
        .maybeSingle();
    final establecimiento = perfil?['establecimiento_id'];
    if (establecimiento == null) return const {};
    final filas = await _cliente
        .from('stock')
        .select('producto_id,cantidad')
        .eq('establecimiento_id', establecimiento as String);
    return {for (final f in filas) f['producto_id'] as String: f['cantidad']};
  }

  Future<void> _guardarCache(Catalogo c) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _claveCache,
      jsonEncode({
        'categorias': c.categorias.map((e) => e.toJson()).toList(),
        'productos': c.productos.map((e) => e.toJson()).toList(),
        'fiscal': c.fiscal.toJson(),
      }),
    );
  }

  Future<Catalogo?> _leerCache() async {
    final prefs = await SharedPreferences.getInstance();
    final contenido = prefs.getString(_claveCache);
    if (contenido == null) return null;
    final datos = jsonDecode(contenido) as Map<String, dynamic>;
    return Catalogo(
      categorias: (datos['categorias'] as List<dynamic>)
          .map((e) => CategoriaPos.fromJson(e as Map<String, dynamic>))
          .toList(),
      productos: (datos['productos'] as List<dynamic>)
          .map((e) => ProductoPos.fromJson(e as Map<String, dynamic>))
          .toList(),
      fiscal: ConfiguracionFiscal.fromJson(
        datos['fiscal'] as Map<String, dynamic>,
      ),
      desdeCache: true,
    );
  }

  Future<List<ClientePos>> buscarClientes(String consulta) async {
    final seguro = consulta.replaceAll(RegExp(r'[,()%*]'), ' ').trim();
    if (seguro.isEmpty) return const [];
    final filas = await _cliente
        .from('clientes')
        .select('id,tipo_documento,numero_documento,nombre,direccion,telefono')
        .eq('activo', true)
        .or('numero_documento.ilike.%$seguro%,nombre.ilike.%$seguro%')
        .limit(20);
    return filas.map(ClientePos.fromJson).toList();
  }

  Future<Map<String, dynamic>> empresa() async {
    final fila = await _cliente
        .from('empresa')
        .select('ruc,razon_social,nombre_comercial,direccion')
        .eq('id', 1)
        .maybeSingle();
    return fila ?? const {};
  }

  Stream<Map<String, dynamic>> comprobanteEnVivo(String id) => _cliente
      .from('comprobantes')
      .stream(primaryKey: ['id'])
      .eq('id', id)
      .where((filas) => filas.isNotEmpty)
      .map((filas) => filas.first);

  String? urlImagen(String? ruta) => ruta == null || ruta.isEmpty
      ? null
      : _cliente.storage.from('imagenes').getPublicUrl(ruta);
}
