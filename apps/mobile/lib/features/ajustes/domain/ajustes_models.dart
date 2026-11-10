const String rucEmpresaDePrueba = '20000000001';

enum RequisitoProduccion {
  rucEmpresa('Falta registrar el RUC de la empresa'),
  rucDePrueba('Registra el RUC real de tu empresa'),
  usuarioSol('Falta registrar el usuario SOL'),
  claveSol('Falta registrar la clave SOL'),
  certificado('Falta subir el certificado digital'),
  certificadoVencido('El certificado digital está vencido: sube uno vigente');

  const RequisitoProduccion(this.descripcion);

  final String descripcion;
}

const int diasAvisoVencimientoCertificado = 30;

class EstadoSunat {
  const EstadoSunat({
    required this.entorno,
    required this.usuarioSol,
    required this.tieneClaveSol,
    required this.tieneCertificado,
    required this.certificadoVenceEn,
    required this.certificadoTitular,
    required this.tieneGre,
    required this.envioBoletas,
  });

  final String entorno;
  final String? usuarioSol;
  final bool tieneClaveSol;
  final bool tieneCertificado;
  final DateTime? certificadoVenceEn;
  final String? certificadoTitular;
  final bool tieneGre;
  final String envioBoletas;

  bool get enProduccion => entorno == 'produccion';
  bool get tieneUsuarioSol => usuarioSol?.isNotEmpty ?? false;

  factory EstadoSunat.desdeJson(Map<String, dynamic> json) => EstadoSunat(
    entorno: json['entorno'] as String? ?? 'beta',
    usuarioSol: json['usuario_sol'] as String?,
    tieneClaveSol: json['tiene_clave_sol'] as bool? ?? false,
    tieneCertificado: json['tiene_certificado'] as bool? ?? false,
    certificadoVenceEn: DateTime.tryParse(
      json['certificado_vence_en'] as String? ?? '',
    ),
    certificadoTitular: json['certificado_titular'] as String?,
    tieneGre: json['tiene_gre'] as bool? ?? false,
    envioBoletas: json['envio_boletas'] as String? ?? 'individual',
  );

  bool certificadoVencido(DateTime ahora) {
    final vence = certificadoVenceEn;
    return vence != null && vence.isBefore(ahora);
  }

  bool certificadoPorVencer(DateTime ahora) {
    final vence = certificadoVenceEn;
    if (vence == null || vence.isBefore(ahora)) return false;
    return vence.difference(ahora).inDays <= diasAvisoVencimientoCertificado;
  }

  List<RequisitoProduccion> requisitosFaltantes({
    required String rucEmpresa,
    required DateTime ahora,
  }) => [
    if (rucEmpresa.isEmpty) RequisitoProduccion.rucEmpresa,
    if (rucEmpresa == rucEmpresaDePrueba) RequisitoProduccion.rucDePrueba,
    if (!tieneUsuarioSol) RequisitoProduccion.usuarioSol,
    if (!tieneClaveSol) RequisitoProduccion.claveSol,
    if (!tieneCertificado) RequisitoProduccion.certificado,
    if (tieneCertificado && certificadoVencido(ahora))
      RequisitoProduccion.certificadoVencido,
  ];
}

class PasoPruebaSunat {
  const PasoPruebaSunat({
    required this.paso,
    required this.ok,
    required this.detalle,
  });

  final String paso;
  final bool ok;
  final String detalle;

  factory PasoPruebaSunat.desdeJson(Map<String, dynamic> json) =>
      PasoPruebaSunat(
        paso: json['paso'] as String? ?? '',
        ok: json['ok'] as bool? ?? false,
        detalle: json['detalle'] as String? ?? '',
      );
}

class ResultadoPruebaSunat {
  const ResultadoPruebaSunat({
    required this.ok,
    required this.mensaje,
    required this.pasos,
  });

  final bool ok;
  final String mensaje;
  final List<PasoPruebaSunat> pasos;

  factory ResultadoPruebaSunat.desdeJson(Map<String, dynamic> json) =>
      ResultadoPruebaSunat(
        ok: json['ok'] as bool? ?? false,
        mensaje: json['mensaje'] as String? ?? '',
        pasos: (json['pasos'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>()
            .map(PasoPruebaSunat.desdeJson)
            .toList(),
      );
}

const String plantillaPdfPorDefecto = 'clasica';

class PlantillaPdf {
  const PlantillaPdf({
    required this.valor,
    required this.etiqueta,
    required this.descripcion,
  });

  final String valor;
  final String etiqueta;
  final String descripcion;
}

const List<PlantillaPdf> plantillasPdf = [
  PlantillaPdf(
    valor: 'clasica',
    etiqueta: 'Principal',
    descripcion: 'Formato tradicional con recuadros y encabezado completo.',
  ),
  PlantillaPdf(
    valor: 'moderna',
    etiqueta: 'Moderna',
    descripcion: 'Bloques de color y jerarquía visual marcada.',
  ),
  PlantillaPdf(
    valor: 'minimalista',
    etiqueta: 'Minimalista',
    descripcion: 'Sin recuadros, líneas finas y mucho espacio en blanco.',
  ),
  PlantillaPdf(
    valor: 'ejecutiva',
    etiqueta: 'Ejecutiva',
    descripcion: 'Aspecto sobrio y formal para clientes corporativos.',
  ),
  PlantillaPdf(
    valor: 'compacta',
    etiqueta: 'Compacta',
    descripcion: 'Texto reducido para que quepa más detalle por hoja.',
  ),
];

class DatosEmpresa {
  const DatosEmpresa({
    required this.ruc,
    required this.razonSocial,
    required this.nombreComercial,
    required this.ubigeo,
    required this.departamento,
    required this.provincia,
    required this.distrito,
    required this.direccion,
    required this.telefono,
    required this.correo,
    required this.logoPath,
    required this.plantillaPdf,
  });

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
  final String plantillaPdf;

  factory DatosEmpresa.desdeJson(Map<String, dynamic> json) => DatosEmpresa(
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
    plantillaPdf: json['plantilla_pdf'] as String? ?? plantillaPdfPorDefecto,
  );
}

class Establecimiento {
  const Establecimiento({
    required this.id,
    required this.codigo,
    required this.nombre,
  });

  final String id;
  final String codigo;
  final String nombre;

  factory Establecimiento.desdeJson(Map<String, dynamic> json) =>
      Establecimiento(
        id: json['id'] as String,
        codigo: json['codigo'] as String? ?? '',
        nombre: json['nombre'] as String? ?? '',
      );
}

class SerieComprobante {
  const SerieComprobante({
    required this.id,
    required this.establecimientoId,
    required this.tipo,
    required this.serie,
    required this.ultimo,
    required this.activa,
  });

  final String id;
  final String establecimientoId;
  final String tipo;
  final String serie;
  final int ultimo;
  final bool activa;

  factory SerieComprobante.desdeJson(Map<String, dynamic> json) =>
      SerieComprobante(
        id: json['id'] as String,
        establecimientoId: json['establecimiento_id'] as String? ?? '',
        tipo: json['tipo'] as String? ?? '',
        serie: json['serie'] as String? ?? '',
        ultimo: (json['ultimo'] as num?)?.toInt() ?? 0,
        activa: json['activa'] as bool? ?? true,
      );
}

class UsuarioSistema {
  const UsuarioSistema({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.establecimientoId,
    required this.activo,
  });

  final String id;
  final String nombre;
  final String? correo;
  final String rol;
  final String? establecimientoId;
  final bool activo;

  factory UsuarioSistema.desdeJson(Map<String, dynamic> json) => UsuarioSistema(
    id: json['id'] as String,
    nombre: json['nombre'] as String? ?? '',
    correo: json['correo'] as String?,
    rol: json['rol'] as String? ?? 'cajero',
    establecimientoId: json['establecimiento_id'] as String?,
    activo: json['activo'] as bool? ?? true,
  );
}

const Map<String, String> tiposSerie = {
  '01': 'Factura',
  '03': 'Boleta',
  '07': 'Nota de crédito',
  '08': 'Nota de débito',
  '09': 'Guía de remisión',
  'NV': 'Nota de venta',
};
