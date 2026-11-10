# Guía SUNAT para el operador

Pasos para que la empresa emita comprobantes válidos: crear el usuario SOL secundario, obtener y cargar el certificado, probar en beta y pasar a producción.

Los nombres de los menús de SUNAT cambian con el tiempo, y los requisitos dependen de la situación de cada contribuyente. Confirma los pasos en el portal de SUNAT o con tu contador antes de ejecutarlos.

## Antes de empezar

Necesitas:

- RUC activo y con domicilio habido.
- Usuario principal y clave SOL del titular.
- Condición de emisor electrónico para el sistema **SEE - Del Contribuyente**, que es el que usa esta aplicación. Verifícala o solicítala en SUNAT Operaciones en Línea.
- Un certificado digital a nombre de la empresa, con su contraseña.

## Usuario SOL secundario

Usa un usuario secundario para no entregar el principal, y porque así puedes revocarlo sin afectar al resto de tus trámites.

1. Entra a **SUNAT Operaciones en Línea** con RUC, usuario principal y clave SOL.
2. Abre **Administración de usuarios secundarios** y crea un usuario.
3. Asígnale solo los perfiles de emisión electrónica y de consulta de comprobantes.
4. Anota el usuario y la clave en un gestor de contraseñas.

En la app escribe únicamente el usuario (por ejemplo `FACTURA1`), sin anteponer el RUC.

## Certificado digital

1. Obtén el certificado de una entidad acreditada por INDECOPI, o solicita el certificado que ofrece SUNAT si tu empresa cumple las condiciones.
2. Pide el archivo en formato **.pfx** o **.p12**. Debe incluir la clave privada y el RUC de la empresa.
3. En SUNAT Operaciones en Línea, registra el certificado en la opción de certificados del SEE - Del Contribuyente. Allí se sube la parte pública.
4. Anota la fecha de vencimiento y programa la renovación con al menos 30 días de margen. Con el certificado vencido no se puede firmar.

No envíes el certificado ni su contraseña por correo o chat, y no lo guardes en el repositorio.

## Credenciales para guías de remisión

Solo si vas a emitir guías electrónicas. En SUNAT Operaciones en Línea, busca la opción **Credenciales API SUNAT** y genera un `client_id` y un `client_secret`. Si otro sistema ya usa esas credenciales, coordina antes de regenerarlas.

## Configuración en la app

Entra como administrador a **Ajustes > SUNAT**.

1. Escribe usuario SOL y clave, y opcionalmente las credenciales de guías.
2. Elige el envío de boletas:
   - **Individual**: cada boleta se envía al emitirla.
   - **Resumen diario**: las boletas se informan agrupadas.
3. Sube el `.pfx`, `.p12` o `.pem` con su contraseña. La aplicación rechaza el archivo si la clave no corresponde al certificado, si está vencido o si pertenece a otro RUC.
4. Pulsa **Probar conexión**.

La app nunca vuelve a mostrar las claves ni el certificado: solo indica si están configurados.

## Pruebas en beta

La instalación arranca en `beta`. Ahí los comprobantes no tienen validez tributaria y el servidor usa las credenciales y el certificado demo, salvo que hayas subido el tuyo.

El entorno beta es compartido entre muchos contribuyentes y a veces está inestable. Un fallo aislado o una respuesta de "ya presentado" no indica necesariamente un problema de tu instalación.

Prueba como mínimo:

- [ ] Factura gravada a un cliente con RUC.
- [ ] Boleta con DNI y boleta sin documento, hasta S/ 700.
- [ ] Boleta sin documento por más de S/ 700: debe rechazarse antes de enviar.
- [ ] Venta con productos exonerados e inafectos, si los manejas.
- [ ] Producto con ICBPER, si vendes bolsas.
- [ ] Factura a crédito con cuotas y factura con detracción, si aplican.
- [ ] Nota de crédito y nota de débito.
- [ ] Anulación de una factura y de una boleta dentro del plazo.
- [ ] Resumen diario, si elegiste ese modo.
- [ ] Guía de remisión, si la vas a usar.
- [ ] Apertura y cierre de caja con venta en efectivo.
- [ ] PDF A4 y ticket, con impresión en tu impresora.
- [ ] Reintento: con el servicio caído, el comprobante se envía solo cuando vuelve.

## Paso a producción

**Este cambio hace que todo lo que emitas tenga validez tributaria.** Hazlo fuera del horario de venta.

Verifica:

- [ ] Eres emisor electrónico del SEE - Del Contribuyente para este RUC.
- [ ] El certificado está registrado en SUNAT, vigente y cargado en la app.
- [ ] Usuario y clave SOL son los reales y **Probar conexión** sale correcto.
- [ ] Datos de la empresa completos: RUC, razón social, ubigeo y dirección.
- [ ] El código de establecimiento coincide con el anexo registrado en SUNAT (`0000` para el principal).
- [ ] En **Ajustes > Series**, el último número de cada serie continúa tu numeración real. Si ya emitías con otro sistema, usa series nuevas o continúa desde el último número emitido.
- [ ] IGV y modalidad de precios (con o sin IGV) confirmados con tu contador.
- [ ] Copia de seguridad de la base disponible y `CLAVE_CIFRADO` respaldada.

Cambia el entorno:

1. En **Ajustes > SUNAT** elige **Producción**.
2. Escribe el RUC para confirmar. El cambio se rechaza si falta el usuario SOL, la clave o un certificado vigente del RUC.
3. Emite un comprobante real de bajo importe, con un cliente de confianza.
4. Confirma que llega a `aceptado` y que aparece en la consulta de comprobantes de SUNAT.

Los comprobantes conservan el entorno en el que se emitieron.

## Operación diaria

| Estado | Significado | Qué hacer |
|---|---|---|
| `pendiente`, `enviando` | En cola o en envío | Esperar. El sistema reintenta hasta 7 veces |
| `por_resumen` | Boleta a la espera del resumen diario | Nada, salvo que el resumen falle |
| `aceptado` | Válido | Nada |
| `observado` | Válido, con observaciones | Leer la nota y corregir en los siguientes |
| `rechazado` | No válido | Corregir el dato y emitir uno nuevo. No se reintenta |
| `error` | No se pudo completar | Revisar el motivo y usar **Reenviar** |
| `por_anular` | Anulación en trámite | Esperar la respuesta de SUNAT |
| `anulado` | Anulado | Nada |
| `no_aplica` | Nota de venta, no va a SUNAT | Nada |

| Código SUNAT | Significado | Acción |
|---|---|---|
| `0` | Aceptado | Ninguna |
| `0100`, `0109`, `0130` a `0138`, `0200` a `0204` | Fallo temporal de SUNAT | Reintento automático |
| `0101` a `0106`, `0110` a `0114` | Credenciales o perfil | Revisar usuario, clave y perfiles. No se reintenta |
| `1033` | Ya presentado | El sistema recupera el CDR por consulta |
| `2000` a `3999` | Rechazo | Corregir y emitir uno nuevo |
| `4000` o más | Observación | Sigue siendo válido |

### Cómo anular

| Documento | Dentro de 7 días | Pasado el plazo |
|---|---|---|
| Factura y sus notas | Comunicación de baja | Nota de crédito |
| Boleta y sus notas | Resumen diario con estado de anulación | Nota de crédito |
| Nota de venta | Anulación local | Anulación local |

Al anular se repone el stock de los productos que lo controlan.

## Renovar credenciales

- **Certificado**: registra el nuevo en SUNAT y súbelo en **Ajustes > SUNAT** antes de que venza el anterior.
- **Clave SOL**: si la cambias en SUNAT, actualízala también en la app. Mientras no coincidan, los envíos fallarán con error de credenciales.
- **Salida de un encargado**: cambia la clave del usuario secundario o crea otro, y desactiva su usuario en la app.
