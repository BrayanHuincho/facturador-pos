# Supabase

Base de datos, login, archivos y tiempo real del proyecto.

## Migraciones

| Archivo | Qué crea |
|---|---|
| `..._tablas.sql` | Tablas, restricciones e índices |
| `..._seguridad.sql` | Roles, funciones y políticas RLS |
| `..._usuarios_nuevos.sql` | Perfil automático al crear un usuario; el primero es administrador |
| `..._realtime.sql` | Tablas que avisan cambios a la app |
| `..._storage.sql` | Buckets de documentos e imágenes |
| `..._modulos_y_medios_pago.sql` | Módulos activables y medios de pago |
| `..._perfil_foto.sql` | Foto de perfil |

## Uso local

```bash
npx supabase start
npx supabase db reset
```

`db reset` borra todo y vuelve a aplicar las migraciones y `seed.sql`.

## Seguridad

- Todas las tablas tienen RLS. El cajero solo ve lo suyo, y el administrador y el contador ven todo.
- La configuración de SUNAT y la cola de trabajos no son accesibles desde la app: solo la API las lee.
- El registro público está desactivado. La primera cuenta que se cree será administradora, así que créala antes de exponer el proyecto.
