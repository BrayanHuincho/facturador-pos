# Contrato técnico de Facturador POS

Fuente única de verdad entre componentes. Producto: POS móvil con facturación electrónica SUNAT (Perú) para **una sola empresa por despliegue**.

Las reglas tributarias y de envío vienen de un sistema anterior propio, ya probado contra SUNAT.

## Reglas de código

- Sin comentarios en el código, en ningún lenguaje. Los nombres deben explicar la intención.
- Identificadores de dominio en español; términos técnicos en inglés cuando sea lo natural.
- Nada de secretos en el repositorio. Las credenciales demo de SUNAT se leen de variables de entorno.
- Dinero en cálculo con `decimal.js` (API) o `Decimal` (Flutter). Nunca `number`/`double` para importes.
- El servidor recalcula siempre los importes.
- Cada agente toca solo su carpeta. Si necesitas algo de otra área, cíñete a este contrato.

## Estructura

```
apps/mobile/              Flutter POS
services/api/             Node 24, TypeScript, Fastify 5 (API y worker)
services/sunat-gateway/   PHP 8.3 + greenter/lite, sin estado
supabase/                 migraciones, seed, config
docs/                     documentación
```

## Flujo

1. La app inicia sesión con Supabase Auth y envía el JWT a la API (`Authorization: Bearer`).
2. Lecturas y CRUD de maestros: Flutter directo a Supabase con RLS. Estado de comprobantes por Realtime.
3. Operaciones críticas (emitir, anular, credenciales, caja, usuarios): siempre por la API.
4. La API inserta en `trabajos`; el worker los toma con `FOR UPDATE SKIP LOCKED`, llama al gateway y guarda XML/CDR/PDF en Storage.

## Base de datos (schema public, snake_case)

Todas con `id uuid pk default gen_random_uuid()` salvo indicación, `creado_en`, `actualizado_en timestamptz`. Importes `numeric(18,2)`, precios unitarios `numeric(18,6)`, cantidades `numeric(18,4)`.

- `empresa` (singleton, `id int pk check (id=1)`): ruc, razon_social, nombre_comercial, ubigeo, departamento, provincia, distrito, direccion, telefono, correo, logo_path, igv_porcentaje default 18, precios_incluyen_igv default true, configurada default false.
- `configuracion_sunat` (singleton, `id int pk check (id=1)`, **sin acceso para clientes**, solo service role): entorno `beta|produccion` default beta, usuario_sol, clave_sol_cifrada, certificado_cifrado, certificado_vence_en, certificado_titular, gre_client_id, gre_client_secret_cifrado, envio_boletas `individual|resumen_diario` default individual.
- Vista `v_configuracion_sunat` (solo rol admin, security definer vía función `obtener_estado_sunat()`): entorno, usuario_sol, tiene_clave_sol, tiene_certificado, certificado_vence_en, certificado_titular, tiene_gre, envio_boletas.
- `perfiles` (`id uuid pk` → auth.users): nombre, rol `admin|cajero|contador`, establecimiento_id, activo, foto_path.
- `establecimientos`: codigo (anexo SUNAT, `0000`), nombre, direccion, ubigeo, activo.
- `series`: establecimiento_id, tipo `01|03|07|08|09|NV`, serie (4 caracteres), ultimo int default 0, activa. Unique (tipo, serie).
- `categorias`: nombre, orden, activa.
- `productos`: codigo, codigo_barras, nombre, descripcion, categoria_id, unidad default `NIU`, precio numeric(18,6) (incluye IGV si aplica), costo, afectacion `10|20|30` default 10, aplica_icbper bool, controla_stock bool, stock_minimo, imagen_path, activo.
- `stock`: producto_id, establecimiento_id, cantidad. Unique (producto_id, establecimiento_id).
- `movimientos_stock`: producto_id, establecimiento_id, tipo `venta|anulacion|ajuste|compra`, cantidad, referencia_id, usuario_id.
- `clientes`: tipo_documento `0|1|4|6|7`, numero_documento, nombre, direccion, ubigeo, telefono, correo, activo. Unique (tipo_documento, numero_documento).
- `turnos_caja`: establecimiento_id, usuario_id, estado `abierto|cerrado`, abierto_en, cerrado_en, monto_apertura, monto_esperado, monto_contado, diferencia, observacion. Índice único parcial: un turno abierto por usuario.
- `movimientos_caja`: turno_id, tipo `ingreso|egreso`, monto, concepto, usuario_id.
- `comprobantes`: establecimiento_id, turno_id, usuario_id, tipo `01|03|07|08|NV`, serie, correlativo int, fecha_emision date, hora_emision time, moneda default PEN, tipo_cambio, forma_pago `contado|credito`, cuotas jsonb, cliente_id, cliente_tipo_documento, cliente_numero_documento, cliente_nombre, cliente_direccion, op_gravadas, op_exoneradas, op_inafectas, op_gratuitas, descuento_total, igv, icbper, total, recibido, vuelto, detraccion jsonb, leyendas jsonb, afectado_id, afectado_tipo, afectado_serie, afectado_correlativo, motivo_codigo, motivo_descripcion, estado, sunat_codigo, sunat_descripcion, sunat_notas jsonb, hash, qr, xml_path, cdr_path, pdf_path, entorno, clave_idempotencia unique, intentos int default 0, resumen_id. Unique (tipo, serie, correlativo).
  - `estado`: `pendiente|enviando|aceptado|observado|rechazado|error|por_resumen|por_anular|anulado|no_aplica` (`no_aplica` = nota de venta).
- `comprobante_items`: comprobante_id, producto_id, orden, codigo, descripcion, unidad, cantidad, precio_unitario, valor_unitario, descuento, afectacion, base, igv, icbper, total.
- `pagos`: comprobante_id, medio `efectivo|yape|plin|transferencia|tarjeta|deposito|otro`, monto, referencia. `monto` se guarda neto del vuelto: la suma de `pagos.monto` es igual a `comprobantes.total`, el vuelto solo sale del efectivo y lo entregado queda en `comprobantes.recibido`. `fecha_emision` es la fecha de America/Lima.
- `resumenes_diarios`: fecha_referencia, fecha_generacion, correlativo, identificador, estado, ticket, sunat_codigo, sunat_descripcion, xml_path, cdr_path, items jsonb, entorno.
- `comunicaciones_baja`: mismos campos que resumen, más comprobante_id.
- `guias_remision`: establecimiento_id, usuario_id, serie, correlativo, fecha_emision, fecha_traslado, motivo_codigo, modalidad `01|02`, peso_total, unidad_peso, bultos, partida_ubigeo, partida_direccion, llegada_ubigeo, llegada_direccion, destinatario_tipo_documento, destinatario_numero_documento, destinatario_nombre, transportista jsonb, conductor jsonb, vehiculo_placa, comprobante_id, estado, ticket, sunat_codigo, sunat_descripcion, xml_path, cdr_path, pdf_path, qr, entorno.
- `guia_items`: guia_id, producto_id, codigo, descripcion, unidad, cantidad.
- `trabajos`: tipo `enviar_comprobante|consultar_ticket|enviar_resumen|enviar_baja|enviar_guia|consultar_guia|generar_resumen_diario`, payload jsonb, estado `pendiente|procesando|hecho|fallido`, intentos, max_intentos default 7, ejecutar_en, bloqueado_en, ultimo_error.
- `auditoria`: usuario_id, accion, entidad, entidad_id, detalle jsonb.

Funciones RLS: `rol_actual()` y `es_admin()`, security definer. `perfiles` activo requerido en todas las políticas.

RLS: lectura de maestros para autenticados activos. Escritura de `categorias`, `productos`, `clientes` para admin; `clientes` también insert/update para cajero. `comprobantes`, `comprobante_items`, `pagos`, `turnos_caja`, `movimientos_caja`, `guias_remision`: solo lectura; el cajero ve lo suyo, admin y contador todo. `configuracion_sunat`, `trabajos`: ningún acceso. Realtime habilitado en `comprobantes`, `guias_remision`, `productos`, `stock`.

Buckets privados: `documentos` (`{entorno}/{ruc}/{archivo}`), públicos: `imagenes` (`productos/`, `logo/`, `perfiles/`). `perfiles/<user-id>.<ext>` solo se escribe vía API con service role.

## API REST (`/api/v1`, JSON, JWT Supabase)

Errores: `{ "error": { "codigo": "TEXTO", "mensaje": "...", "detalles": {} } }`. Permisos entre paréntesis (si no se indica: cualquier usuario activo).

- `GET /salud` (pública)
- `POST /configuracion/inicial` (admin) empresa y establecimiento principal, crea series por defecto
- `GET|PUT /empresa` (PUT admin)
- `PATCH /establecimientos/:id` (admin) `{ nombre?, direccion?, ubigeo? }`, con auditoría
- `GET|POST /series`, `PATCH /series/:id` (admin) `{ establecimiento_id, tipo, serie, activa }`; `ultimo` no es editable una vez emitido un comprobante
- `GET /sunat/configuracion` (admin) nunca devuelve secretos
- `PUT /sunat/credenciales` (admin) `{ usuario_sol, clave_sol?, gre_client_id?, gre_client_secret?, envio_boletas }`
- `POST /sunat/certificado` (admin) multipart: `archivo` (.pfx/.p12/.pem), `clave`. Valida par clave/certificado, vigencia y RUC
- `DELETE /sunat/certificado` (admin)
- `PUT /sunat/entorno` (admin) `{ entorno, confirmar_ruc }`. Paso a `produccion` exige usuario SOL, clave y certificado vigente del RUC; `confirmar_ruc` debe coincidir
- `POST /sunat/probar` (admin) prueba de conexión
- `POST /comprobantes` cabecera `Idempotency-Key` obligatoria. Cuerpo: `{ tipo, serie?, cliente: {tipo_documento,numero_documento,nombre,direccion?} | cliente_id, items: [{producto_id?, codigo?, descripcion?, unidad?, cantidad, precio_unitario?, descuento?, afectacion?}], pagos: [{medio,monto,referencia?}], forma_pago?, cuotas?, detraccion?, moneda?, tipo_cambio?, observacion? }`. Requiere turno abierto si hay pago en efectivo. Devuelve el comprobante completo
- `POST /comprobantes/previsualizar` totales sin guardar
- `POST /comprobantes/vista-previa?formato=a4|ticket80|ticket58` mismo cuerpo que `POST /comprobantes`: PDF del documento con número «POR EMITIR», sin QR ni hash, sello de vista previa; no guarda ni consume correlativo
- `POST /comprobantes/notas` nota de crédito/débito
- `GET /comprobantes/:id`
- `POST /comprobantes/:id/reenviar`, `/consultar`
- `POST /comprobantes/:id/anular` (admin) `{ motivo }`
- `GET /comprobantes/:id/archivo/:tipo` tipo `pdf-a4|pdf-ticket80|pdf-ticket58|xml|cdr`: `{ url }` firmada
- `GET|POST /resumenes`, `POST /resumenes/:id/consultar`; `GET /bajas` (admin, contador)
- `POST /guias`, `GET /guias/:id`, `POST /guias/:id/reenviar`; `GET /guias/:id/archivo/pdf` regenera el PDF con el estado vigente
- `GET /caja/turno-actual`, `POST /caja/abrir` `{monto_apertura}`, `POST /caja/cerrar` `{monto_contado, observacion?}`, `POST /caja/movimientos` `{tipo,monto,concepto}`, `GET /caja/turnos/:id/resumen`
- `POST /stock/ajustes` (admin) `{producto_id, establecimiento_id, cantidad, motivo}`
- `GET|POST /usuarios`, `PATCH /usuarios/:id` (admin)
- `PATCH /perfil` `{nombre}` cambia el nombre del propio usuario, con auditoría
- `POST /perfil/foto` multipart, campo `archivo`: png, jpeg o webp validado por contenido, hasta 5 MiB; se guarda en `imagenes/perfiles/<user-id>.<ext>`, con auditoría
- `DELETE /perfil/foto` quita la foto, con auditoría
- `GET /consultas/documento/:tipo/:numero` RUC/DNI
- `GET /reportes/resumen?desde&hasta`, `/reportes/ventas?desde&hasta&agrupar=dia|producto|medio|usuario`, `/reportes/exportar?desde&hasta` CSV

## Reglas tributarias y SUNAT

Reglas principales:

- HALF_UP, 2 decimales. Precio incluido: `importe=round(cant*precio)-desc; base=round(importe/(1+f)); igv=importe-base`.
- Boleta a cliente sin documento solo hasta S/ 700. Factura exige RUC.
- Reintentos: transitorios `0100,0109,0130-0138,0200-0204`, HTTP y red, 7 veces, 20 s exponencial. Credenciales `0101-0106,0110-0114`: error sin reintento. `2000-3999` rechazado sin reintento. `>=4000` observado. `0` aceptado. `1033`: recuperar CDR por consulta.
- Anulación: dentro de 7 días boleta y sus notas por RC estado 3; factura y sus notas por RA; pasado el plazo, nota de crédito. Nota de venta: anulación local.
- ICBPER S/ 0.50 por unidad cuando `aplica_icbper`.
- La venta descuenta stock si `controla_stock`; la anulación lo repone.
- Beta usa las credenciales demo públicas desde `SUNAT_DEMO_USUARIO` / `SUNAT_DEMO_CLAVE` y certificado demo, salvo que la empresa haya subido el suyo.
- El certificado y las claves se cifran con AES-256-GCM (`CLAVE_CIFRADO`, formato `v1:iv:tag:data`), solo la API los descifra.

## Gateway SUNAT

Rutas y formatos JSON: `/factura`, `/nota`, `/resumen`, `/baja`, `/ticket`, `/consulta-cpe`, `/firmar`, `/probar`, `/guia`, `/guia-estado`, `/pdf`, `GET /salud`; autenticación `X-Token-Interno`. Puerto 4210.

## Plantillas de impresión

Sin cotizaciones en ninguna capa. Los PDF se generan únicamente en el gateway (ruta `/pdf`, Blade + dompdf) y solo para boleta, factura, notas de crédito/débito, nota de venta y guía.

`empresa.plantilla_pdf` text default `clasica`, valores `clasica|moderna|minimalista|ejecutiva|compacta`. `clasica` es la plantilla principal, sin cambios de diseño. Cada plantilla existe en A4, ticket 80 mm y ticket 58 mm, y cumple los mismos requisitos legales: RUC, tipo y número, cliente, detalle, totales, monto en letras, QR, hash y leyenda de representación impresa.

`/pdf` acepta el campo adicional `plantilla` (si falta, `clasica`). `GET /empresa` y `PUT /empresa` incluyen `plantilla_pdf`. `pdf/generar.ts` llama al gateway con la plantilla de la empresa. La pantalla `/ajustes/empresa` permite elegirla.

Marca de agua: `datos.sello` se imprime en diagonal detrás del contenido en todas las plantillas y formatos: `PRUEBA` (ámbar, beta), `ANULADO` y `RECHAZADO` (rojo) y `VISTA PREVIA` (azul grisáceo). `ANULADO` tiene prioridad sobre `PRUEBA` y aplica también mientras la baja está en curso (`por_anular`). Los PDF se regeneran al pedirlos, así que una anulación posterior nunca sirve un PDF sin marca.

## Variables de entorno

API: `PORT=4200`, `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_JWKS_URL`, `SUPABASE_JWT_SECRET` (opcional), `CLAVE_CIFRADO`, `SUNAT_GATEWAY_URL`, `SUNAT_GATEWAY_TOKEN`, `SUNAT_DEMO_USUARIO`, `SUNAT_DEMO_CLAVE`, `CONSULTA_DOCUMENTO_URL`, `CONSULTA_DOCUMENTO_TOKEN`, `CORS_ORIGENES`.

Flutter (`--dart-define-from-file=env.json`): `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `API_URL`.

## Áreas de la API

`services/api/src/`:
- `config/`, `http/` (servidor, errores, auth, permisos), `db/` (pool, `withTransaction`)
- `modulos/empresa`, `modulos/sunat-config`, `modulos/usuarios`, `modulos/consultas`
- `modulos/comprobantes` + `dominio/tributos`
- `modulos/caja`, `modulos/stock`, `modulos/reportes`
- `sunat/` (cliente gateway, catálogos), `modulos/resumenes`, `modulos/guias`, `pdf/`, `cola/` (worker)

Cada módulo exporta `async function <nombre>Rutas(app: FastifyInstance)`; `http/rutas.ts` los registra.

Firmas compartidas fijas:
- `db/pool.ts`: `pool`, `withTransaction<T>(fn: (c: PoolClient) => Promise<T>): Promise<T>`
- `http/errores.ts`: `class ErrorApi(status: number, codigo: string, mensaje: string, detalles?: unknown)`
- `http/auth.ts`: `request.usuario: { id, rol, establecimiento_id }`, `requerirRol(...roles)` como `preHandler`; ruta autenticada por defecto
- `config/entorno.ts`: `entorno` validado con zod
- `config/cifrado.ts`: `cifrar(texto)`, `descifrar(texto)`
- `cola/encolar.ts`: `encolar(c: PoolClient, tipo, payload, ejecutarEn?)`
- `sunat/config.ts`: `obtenerCredencialesSunat(c)` descifradas según entorno
- `pdf/generar.ts`: `generarPdfComprobante(comprobanteId, formato): Promise<Buffer>`
- `storage/archivos.ts`: `subirDocumento(ruta, buffer, tipo)`, `urlFirmada(ruta)`

## Áreas de Flutter

`apps/mobile/lib/`: `core/` (env, tema, router, api_client, errores, formatos, widgets), `features/<feature>/{data,domain,presentation}`. Riverpod sin generación de código (`Notifier`, `FutureProvider`). Sin freezed ni build_runner.

`core/api/api_client.dart`: `apiClientProvider`, clase `ApiClient` con `get/post/put/patch/delete<T>` que devuelven JSON y lanzan `ApiException(codigo, mensaje)`. `core/router/rutas.dart` define constantes; cada feature exporta `List<RouteBase> <feature>Routes` y `core/router/router.dart` las agrega.

Rutas: `/login`, `/onboarding`, `/pos`, `/pos/cobro`, `/comprobantes`, `/comprobantes/:id`, `/caja`, `/productos`, `/productos/:id`, `/clientes`, `/guias`, `/reportes`, `/ajustes`, `/ajustes/perfil`, `/ajustes/sunat`, `/ajustes/empresa`, `/ajustes/series`, `/ajustes/usuarios`, `/ajustes/impresora`.
