# API

Servicio en Node y Fastify que hace todo lo que no conviene dejar en manos de la app: emitir, anular, manejar caja y stock, administrar usuarios y guardar las credenciales de SUNAT.

En el mismo código vive el worker, que toma los comprobantes pendientes de una cola en Postgres y los envía a SUNAT a través del gateway.

## Ejecutar

Lo más simple es `scripts/levantar-local.ps1` desde la raíz, que también crea el `.env`. A mano:

```bash
npm ci
npm run dev
npm run worker
```

Cada uno corre en su propia terminal. La API queda en `/api/v1` y responde `GET /salud`.

## Cómo está organizada

```
src/
  http/       servidor, autenticación con el JWT de Supabase y manejo de errores
  modulos/    una carpeta por área: comprobantes, caja, stock, reportes, usuarios...
  dominio/    cálculo de impuestos y reglas de SUNAT, sin dependencias externas
  cola/       motor de trabajos con FOR UPDATE SKIP LOCKED y reintentos
  sunat/      cliente del gateway y clasificación de respuestas
  pdf/        arma lo que el gateway convierte en PDF
  config/     variables de entorno validadas y cifrado
```

## Decisiones que conviene conocer

- **Idempotencia:** `POST /comprobantes` exige `Idempotency-Key`. Con la misma clave y el mismo cuerpo devuelve el comprobante original; con otro cuerpo responde `409`.
- **Importes:** se recalculan siempre en el servidor con `decimal.js`, y nunca se confía en los totales que manda la app.
- **Credenciales:** la clave SOL y el certificado se guardan cifrados con AES-256-GCM y nunca salen en respuestas ni en logs.
- **Producción:** solo se activa con usuario SOL, clave, un certificado vigente del mismo RUC y el RUC escrito para confirmar.

## Pruebas

```bash
npm run typecheck
npm test
```
