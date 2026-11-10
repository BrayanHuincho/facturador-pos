# Despliegue

Guía para poner en marcha una instancia de Facturador POS. Cada empresa tiene su propio proyecto Supabase y su propio servidor.

Orden recomendado: Supabase, API y gateway, primer administrador, APK.

## 1. Supabase remoto

1. Crea un proyecto en [supabase.com](https://supabase.com) y anota su referencia (`<ref>`) y la contraseña de la base. Elige la región más cercana a tus usuarios.
2. Vincula el repositorio y aplica las migraciones:

   ```bash
   supabase login
   supabase link --project-ref <ref>
   supabase db push
   ```

   `db push` no aplica el seed, y así debe ser en una instancia real: `supabase/seed.sql` solo contiene un catálogo de muestra para desarrollo.

3. Reúne estos valores del panel del proyecto:

   | Dato | Dónde | Se usa en |
   |---|---|---|
   | URL del proyecto | Project Settings > API | `SUPABASE_URL` en API y app |
   | Clave anon | Project Settings > API Keys | `SUPABASE_ANON_KEY`, solo en la app |
   | Clave de servicio | Project Settings > API Keys | `SUPABASE_SERVICE_ROLE_KEY`, solo en el servidor |
   | Cadena de conexión | Botón Connect, Session pooler | `DATABASE_URL` |

   La conexión directa de Supabase usa IPv6 de forma predeterminada. Desde un servidor solo IPv4 usa el Session pooler:

   ```
   postgresql://postgres.<ref>:<contraseña>@<host-del-pooler>:5432/postgres
   ```

4. `SUPABASE_JWKS_URL` se deriva de `SUPABASE_URL` si la dejas vacía. Si tu proyecto todavía firma los JWT con el secreto compartido (HS256), define también `SUPABASE_JWT_SECRET`.
5. En Authentication > Providers deja activo Email y desactiva el registro público (*Allow new users to sign up*). Los usuarios se crean desde la API.
6. Comprueba en Storage que existen los buckets `documentos` (privado) e `imagenes` (público). Comprueba también que `comprobantes`, `guias_remision`, `productos` y `stock` estén en la publicación de Realtime.

## 2. API, worker y gateway

La API y el worker comparten imagen (`services/api/Dockerfile`). El gateway tiene la suya. Cualquier servidor o plataforma que ejecute contenedores sirve. La forma más directa es un VPS con Docker.

### Con Docker Compose en un VPS

```bash
git clone <url-del-repositorio> facturador
cd facturador
cp .env.example .env
```

Rellena `.env`. Genera `CLAVE_CIFRADO` y `SUNAT_GATEWAY_TOKEN` por separado:

```bash
openssl rand -hex 32
```

Protege el archivo y arranca:

```bash
chmod 600 .env
docker compose up -d --build
docker compose ps
curl http://localhost:4200/api/v1/salud
```

**Respalda `CLAVE_CIFRADO` fuera del servidor.** Si se pierde o cambia, las credenciales SOL y el certificado guardados dejan de poder descifrarse y hay que volver a cargarlos.

### HTTPS

La app debe llegar a la API por HTTPS: Android bloquea el tráfico sin cifrar en las versiones de producción. Coloca un proxy inverso delante del puerto 4200. Con Caddy basta este `Caddyfile`:

```
api.tudominio.pe {
    reverse_proxy 127.0.0.1:4200
}
```

Con proxy inverso, define `TRUST_PROXY=true` en `.env`. Cierra el puerto 4200 en el firewall para que solo se acceda por el proxy. Ten en cuenta que Docker publica puertos saltándose `ufw`, así que conviene cambiar el mapeo a `127.0.0.1:4200:4200` en el servidor o filtrar en el firewall del proveedor. El gateway ya se publica solo en `127.0.0.1` y nunca debe quedar expuesto a Internet.

### En una plataforma de contenedores

Despliega tres servicios desde el repositorio:

| Servicio | Contexto de build | Comando | Expuesto |
|---|---|---|---|
| API | `services/api` | el predeterminado | Sí, HTTPS al puerto 4200 |
| Worker | `services/api` | `node dist/worker.js` | No |
| Gateway | `services/sunat-gateway` | el predeterminado | Solo en red privada, puerto 4210 |

Requisitos:

- El worker debe estar siempre encendido: sin él, los comprobantes se quedan en `pendiente`. No uses planes que suspendan el proceso por inactividad.
- Da al gateway el token en la variable que lea su imagen, con el mismo valor que `SUNAT_GATEWAY_TOKEN` de la API.
- Apunta `SUNAT_GATEWAY_URL` a la dirección privada del gateway.
- Guarda las variables en el gestor de secretos de la plataforma.

### Actualizar

```bash
git pull
supabase db push
docker compose up -d --build
```

Aplica primero las migraciones si el código nuevo depende de ellas.

## 3. Primer administrador

1. Crea el usuario en Authentication > Users, con correo y contraseña confirmados. **El primer usuario del proyecto queda como administrador activo de forma automática**, así que crea primero el de la persona responsable.
2. Inicia sesión en la app. El asistente de `/onboarding` registra la empresa y el establecimiento principal, y crea las series por defecto.

Después sigue [SUNAT.md](SUNAT.md) para cargar las credenciales. La instancia arranca en `beta`.

## 4. Construir el APK

Crea `apps/mobile/env.json` con los valores de producción:

```json
{
  "SUPABASE_URL": "https://<ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<clave anon>",
  "API_URL": "https://api.tudominio.pe/api/v1"
}
```

Estos valores quedan dentro del APK y cualquiera puede extraerlos. **Nunca pongas ahí la clave de servicio.**

### Firma

El proyecto de Android todavía firma las versiones `release` con la clave de depuración (`apps/mobile/android/app/build.gradle.kts`). Sirve para pruebas internas, pero no para distribuir: Android no aceptará actualizar la app si luego cambia la firma.

Antes de la primera entrega real:

1. Genera un almacén de claves fuera del repositorio:

   ```bash
   keytool -genkey -v -keystore facturador.jks -keyalg RSA -keysize 2048 -validity 10000 -alias facturador
   ```

2. Crea `apps/mobile/android/key.properties` con `storePassword`, `keyPassword`, `keyAlias` y `storeFile`. Tanto este archivo como `*.jks` están ignorados por git.
3. Cambia `build.gradle.kts` para que `release` use esa firma, siguiendo la [guía oficial de Flutter](https://docs.flutter.dev/deployment/android#sign-the-app).
4. Guarda el almacén y sus contraseñas en un lugar seguro. Sin ellos no podrás publicar actualizaciones.

### Compilar

```bash
cd apps/mobile
flutter pub get
flutter build apk --release --dart-define-from-file=env.json
```

El resultado queda en `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`. Para Google Play usa `flutter build appbundle --release --dart-define-from-file=env.json`.

## Verificación final

- [ ] `GET /api/v1/salud` responde por HTTPS.
- [ ] `docker compose ps` muestra `api` y `gateway` como `healthy`, y `worker` en ejecución.
- [ ] Con la app se inicia sesión y se completa el onboarding.
- [ ] Una boleta en beta llega a `aceptado` y se pueden abrir su PDF, XML y CDR.
- [ ] El puerto 4210 no responde desde Internet.
- [ ] `node scripts/escanear-secretos.mjs` termina sin hallazgos.
