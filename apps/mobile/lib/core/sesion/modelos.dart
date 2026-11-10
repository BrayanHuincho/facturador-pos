import 'package:decimal/decimal.dart';

import '../env/env.dart';
import '../formatos/formatos.dart';

enum RolUsuario {
  admin('Administrador'),
  cajero('Cajero'),
  contador('Contador');

  const RolUsuario(this.etiqueta);

  final String etiqueta;

  static RolUsuario desde(String? valor) => RolUsuario.values.firstWhere(
    (rol) => rol.name == valor,
    orElse: () => RolUsuario.cajero,
  );
}

class Perfil {
  const Perfil({
    required this.id,
    required this.nombre,
    required this.rol,
    required this.activo,
    this.establecimientoId,
    this.fotoPath,
    this.actualizadoEn,
  });

  factory Perfil.desdeJson(Map<String, dynamic> json) => Perfil(
    id: json['id'] as String,
    nombre: json['nombre'] as String? ?? '',
    rol: RolUsuario.desde(json['rol'] as String?),
    activo: json['activo'] as bool? ?? false,
    establecimientoId: json['establecimiento_id'] as String?,
    fotoPath: json['foto_path'] as String?,
    actualizadoEn: json['actualizado_en'] as String?,
  );

  final String id;
  final String nombre;
  final RolUsuario rol;
  final bool activo;
  final String? establecimientoId;
  final String? fotoPath;
  final String? actualizadoEn;

  String? get fotoUrl {
    final ruta = fotoPath;
    if (ruta == null) return null;
    final version = Uri.encodeQueryComponent(actualizadoEn ?? '');
    return '${Env.supabaseUrl}/storage/v1/object/public/imagenes/$ruta?v=$version';
  }

  bool get esAdmin => rol == RolUsuario.admin;
}

const mediosPagoPorDefecto = <String>[
  'efectivo',
  'yape',
  'plin',
  'transferencia',
  'tarjeta',
  'deposito',
];

class ModulosEmpresa {
  const ModulosEmpresa({
    required this.caja,
    required this.guias,
    required this.reportes,
    required this.notaVenta,
  });

  factory ModulosEmpresa.desdeJson(Object? json) {
    if (json is! Map) return todos;
    return ModulosEmpresa(
      caja: json['caja'] as bool? ?? true,
      guias: json['guias'] as bool? ?? true,
      reportes: json['reportes'] as bool? ?? true,
      notaVenta: json['nota_venta'] as bool? ?? true,
    );
  }

  static const todos = ModulosEmpresa(
    caja: true,
    guias: true,
    reportes: true,
    notaVenta: true,
  );

  final bool caja;
  final bool guias;
  final bool reportes;
  final bool notaVenta;

  ModulosEmpresa copiar({
    bool? caja,
    bool? guias,
    bool? reportes,
    bool? notaVenta,
  }) => ModulosEmpresa(
    caja: caja ?? this.caja,
    guias: guias ?? this.guias,
    reportes: reportes ?? this.reportes,
    notaVenta: notaVenta ?? this.notaVenta,
  );

  Map<String, bool> toJson() => {
    'caja': caja,
    'guias': guias,
    'reportes': reportes,
    'nota_venta': notaVenta,
  };
}

class Empresa {
  const Empresa({
    required this.ruc,
    required this.razonSocial,
    required this.igvPorcentaje,
    required this.preciosIncluyenIgv,
    required this.configurada,
    this.nombreComercial,
    this.ubigeo,
    this.departamento,
    this.provincia,
    this.distrito,
    this.direccion,
    this.telefono,
    this.correo,
    this.logoPath,
    this.modulos = ModulosEmpresa.todos,
    this.mediosPago = mediosPagoPorDefecto,
    this.qrYapePath,
    this.qrPlinPath,
  });

  factory Empresa.desdeJson(Map<String, dynamic> json) => Empresa(
    ruc: json['ruc'] as String? ?? '',
    razonSocial: json['razon_social'] as String? ?? '',
    nombreComercial: json['nombre_comercial'] as String?,
    ubigeo: json['ubigeo'] as String?,
    departamento: json['departamento'] as String?,
    provincia: json['provincia'] as String?,
    distrito: json['distrito'] as String?,
    direccion: json['direccion'] as String?,
    telefono: json['telefono'] as String?,
    correo: json['correo'] as String?,
    logoPath: json['logo_path'] as String?,
    igvPorcentaje: json['igv_porcentaje'] == null
        ? Decimal.fromInt(18)
        : parseDecimal(json['igv_porcentaje']),
    preciosIncluyenIgv: json['precios_incluyen_igv'] as bool? ?? true,
    configurada: json['configurada'] as bool? ?? false,
    modulos: ModulosEmpresa.desdeJson(json['modulos']),
    mediosPago: json['medios_pago'] is List
        ? [for (final m in json['medios_pago'] as List) '$m']
        : mediosPagoPorDefecto,
    qrYapePath: json['qr_yape_path'] as String?,
    qrPlinPath: json['qr_plin_path'] as String?,
  );

  final String ruc;
  final String razonSocial;
  final String? nombreComercial;
  final String? ubigeo;
  final String? departamento;
  final String? provincia;
  final String? distrito;
  final String? direccion;
  final String? telefono;
  final String? correo;
  final String? logoPath;
  final Decimal igvPorcentaje;
  final bool preciosIncluyenIgv;
  final bool configurada;
  final ModulosEmpresa modulos;
  final List<String> mediosPago;
  final String? qrYapePath;
  final String? qrPlinPath;

  String get nombreVisible => (nombreComercial?.trim().isNotEmpty ?? false)
      ? nombreComercial!
      : razonSocial;
}
