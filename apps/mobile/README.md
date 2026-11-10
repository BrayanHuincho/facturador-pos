# App móvil

La app de Facturador POS, hecha en Flutter. Es la que usa el cajero: vende, cobra, imprime y consulta. El administrador además configura la empresa, los medios de pago y los datos de SUNAT desde aquí.

## Qué tiene

- Venta con búsqueda, categorías, lector de código de barras y vista en lista o en tarjetas.
- Cobro con boleta, factura o nota de venta, varios medios de pago y QR de Yape o Plin.
- Vista previa del comprobante antes de emitirlo.
- Ventas sin internet: quedan en cola y se envían solas al volver la conexión, sin duplicarse.
- Impresión en ticketeras de 58 y 80 mm por Bluetooth o red.
- Comprobantes, guías de remisión, caja, reportes en PDF y CSV.
- Ajustes de SUNAT, empresa, series, usuarios, módulos y perfil.
- Tema claro y oscuro.

## Ejecutarla

El backend tiene que estar corriendo; mira el [README principal](../../README.md). Ese mismo script crea `env.json`.

```powershell
flutter pub get
flutter run --dart-define-from-file=env.json
```

En Android Studio, abre esta carpeta y usa la configuración **Facturador POS**.

`env.json` no se sube al repositorio y tiene esta forma:

```json
{
  "SUPABASE_URL": "http://127.0.0.1:54321",
  "SUPABASE_ANON_KEY": "clave anon de supabase",
  "API_URL": "http://127.0.0.1:14200"
}
```

Con `127.0.0.1` el emulador o el celular por USB llegan a tu PC gracias a `adb reverse`, que el script de arranque ya configura.

## Compilar el APK

```powershell
flutter build apk --release --split-per-abi --dart-define-from-file=env.json
```

Salen tres archivos en `build/app/outputs/flutter-apk/`: `arm64-v8a` para la mayoría de celulares, `armeabi-v7a` para los antiguos y `x86_64` para el emulador.

Por ahora se firma con la clave de debug. Para Play Store hace falta una clave propia.

## Estructura

```
lib/
  core/            sesión, cliente de la API, rutas, formatos y preferencias
  design_system/   colores, tipografía y componentes reutilizables
  features/        una carpeta por pantalla o flujo
    pos/           venta, cobro, vista previa y cola sin conexión
    comprobantes/  listado, detalle, notas y anulación
    ajustes/       SUNAT, empresa, series, usuarios, módulos y perfil
    ...
```

Cada flujo separa `data` (llamadas a la API o a Supabase), `domain` (modelos y reglas) y `presentation` (pantallas). El estado se maneja con Riverpod y los importes siempre con `Decimal`, nunca con `double`.

## Pruebas

```powershell
flutter analyze
flutter test
```
