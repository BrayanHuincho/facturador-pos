$ErrorActionPreference = 'Stop'
$contenedor = 'supabase_db_facturador'
$script = Join-Path $PSScriptRoot 'datos-demo.sql'

docker cp $script "${contenedor}:/tmp/datos-demo.sql"
docker exec $contenedor psql -U postgres -d postgres -v ON_ERROR_STOP=1 -f /tmp/datos-demo.sql
if ($LASTEXITCODE -ne 0) { throw 'No se pudieron cargar los datos demo.' }
