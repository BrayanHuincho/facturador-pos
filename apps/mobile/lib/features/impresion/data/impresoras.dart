import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../domain/impresora.dart';

const _tamanoBloqueBluetooth = 512;
const _pausaBloqueBluetooth = Duration(milliseconds: 80);
const _pausaAntesDeCerrar = Duration(seconds: 1);

class ImpresoraTcp implements Impresora {
  ImpresoraTcp(this.ip, this.puerto);

  final String ip;
  final int puerto;

  @override
  Future<void> enviar(Uint8List bytes) async {
    final Socket socket;
    try {
      socket = await Socket.connect(
        ip.trim(),
        puerto,
        timeout: const Duration(seconds: 5),
      );
    } on SocketException {
      throw FalloImpresora('No se pudo conectar con $ip:$puerto.');
    }
    final escucha = socket.listen(
      (_) {},
      onError: (Object _) {},
      cancelOnError: true,
    );
    try {
      socket.add(bytes);
      await socket.flush().timeout(const Duration(seconds: 20));
      await socket.close().timeout(const Duration(seconds: 5));
    } on SocketException {
      throw FalloImpresora('Se perdió la conexión con $ip:$puerto.');
    } on TimeoutException {
      throw const FalloImpresora('La impresora dejó de responder.');
    } finally {
      await escucha.cancel();
      socket.destroy();
    }
  }
}

class ImpresoraBluetooth implements Impresora {
  ImpresoraBluetooth(this.direccion);

  final String direccion;

  @override
  Future<void> enviar(Uint8List bytes) async {
    try {
      if (!await PrintBluetoothThermal.bluetoothEnabled) {
        throw const FalloImpresora('Activa el Bluetooth del dispositivo.');
      }
      final conectada = await PrintBluetoothThermal.connect(
        macPrinterAddress: direccion,
      );
      if (!conectada) {
        throw const FalloImpresora(
          'No se pudo conectar con la impresora Bluetooth.',
        );
      }
      try {
        for (
          var inicio = 0;
          inicio < bytes.length;
          inicio += _tamanoBloqueBluetooth
        ) {
          final fin = inicio + _tamanoBloqueBluetooth > bytes.length
              ? bytes.length
              : inicio + _tamanoBloqueBluetooth;
          final escrito = await PrintBluetoothThermal.writeBytes(
            bytes.sublist(inicio, fin),
          );
          if (!escrito) {
            throw const FalloImpresora(
              'La impresora Bluetooth rechazó el envío.',
            );
          }
          await Future<void>.delayed(_pausaBloqueBluetooth);
        }
        await Future<void>.delayed(_pausaAntesDeCerrar);
      } finally {
        await PrintBluetoothThermal.disconnect;
      }
    } on PlatformException catch (e) {
      throw FalloImpresora(e.message ?? 'No se pudo usar el Bluetooth.');
    } on MissingPluginException {
      throw const FalloImpresora(
        'Bluetooth no disponible en este dispositivo.',
      );
    }
  }
}

Future<List<DispositivoBluetooth>> dispositivosEmparejados() async {
  try {
    final permitido = await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!permitido) {
      throw const FalloImpresora(
        'Concede el permiso de Bluetooth a la aplicación.',
      );
    }
    final emparejados = await PrintBluetoothThermal.pairedBluetooths;
    return [
      for (final d in emparejados)
        DispositivoBluetooth(nombre: d.name, direccion: d.macAdress),
    ];
  } on PlatformException catch (e) {
    throw FalloImpresora(e.message ?? 'No se pudo leer el Bluetooth.');
  } on MissingPluginException {
    throw const FalloImpresora('Bluetooth no disponible en este dispositivo.');
  }
}

Impresora crearImpresora(ConfigImpresora config) {
  if (!config.configurada) {
    throw const FalloImpresora('Configura la impresora en Ajustes.');
  }
  return switch (config.conexion) {
    ConexionImpresora.bluetooth => ImpresoraBluetooth(
      config.direccionBluetooth!,
    ),
    ConexionImpresora.red => ImpresoraTcp(config.ip, config.puerto),
  };
}
