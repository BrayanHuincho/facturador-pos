import 'dart:typed_data';

enum ConexionImpresora {
  bluetooth('Bluetooth'),
  red('Red (TCP 9100)');

  const ConexionImpresora(this.etiqueta);
  final String etiqueta;
}

enum PapelImpresora {
  mm58('58 mm', 32),
  mm80('80 mm', 48);

  const PapelImpresora(this.etiqueta, this.columnas);
  final String etiqueta;
  final int columnas;
}

class ConfigImpresora {
  const ConfigImpresora({
    this.conexion = ConexionImpresora.bluetooth,
    this.papel = PapelImpresora.mm80,
    this.nombreBluetooth,
    this.direccionBluetooth,
    this.ip = '',
    this.puerto = puertoPorDefecto,
    this.imprimirAlEmitir = false,
  });

  static const puertoPorDefecto = 9100;

  final ConexionImpresora conexion;
  final PapelImpresora papel;
  final String? nombreBluetooth;
  final String? direccionBluetooth;
  final String ip;
  final int puerto;
  final bool imprimirAlEmitir;

  bool get configurada => switch (conexion) {
    ConexionImpresora.bluetooth => (direccionBluetooth ?? '').isNotEmpty,
    ConexionImpresora.red =>
      ip.trim().isNotEmpty && puerto > 0 && puerto < 65536,
  };

  ConfigImpresora copiar({
    ConexionImpresora? conexion,
    PapelImpresora? papel,
    String? nombreBluetooth,
    String? direccionBluetooth,
    String? ip,
    int? puerto,
    bool? imprimirAlEmitir,
  }) => ConfigImpresora(
    conexion: conexion ?? this.conexion,
    papel: papel ?? this.papel,
    nombreBluetooth: nombreBluetooth ?? this.nombreBluetooth,
    direccionBluetooth: direccionBluetooth ?? this.direccionBluetooth,
    ip: ip ?? this.ip,
    puerto: puerto ?? this.puerto,
    imprimirAlEmitir: imprimirAlEmitir ?? this.imprimirAlEmitir,
  );
}

class DispositivoBluetooth {
  const DispositivoBluetooth({required this.nombre, required this.direccion});
  final String nombre;
  final String direccion;
}

class FalloImpresora implements Exception {
  const FalloImpresora(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

abstract interface class Impresora {
  Future<void> enviar(Uint8List bytes);
}
