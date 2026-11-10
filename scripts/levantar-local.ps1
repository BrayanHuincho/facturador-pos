param(
    [int]$PuertoApi = 14200,
    [int]$PuertoGateway = 14211
)

$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$rutaApi = Join-Path $raiz 'services\api'
$rutaEnvMovil = Join-Path $raiz 'apps\mobile\env.json'

Get-CimInstance Win32_Process -Filter "Name='node.exe'" |
    Where-Object { $_.CommandLine -match 'src[\\/](server|worker)\.ts' } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

Set-Location $raiz
cmd /c "npx supabase start >nul 2>&1"
$estado = cmd /c "npx supabase status -o json 2>nul" | Out-String | ConvertFrom-Json

function New-SecretoHex {
    $bytes = New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    ($bytes | ForEach-Object { $_.ToString('x2') }) -join ''
}

$rutaEnvApi = Join-Path $rutaApi '.env'
if (-not (Test-Path $rutaEnvApi)) {
    @(
        "PORT=$PuertoApi",
        'LOG_LEVEL=info',
        "DATABASE_URL=$($estado.DB_URL)",
        "SUPABASE_URL=$($estado.API_URL)",
        "SUPABASE_SERVICE_ROLE_KEY=$($estado.SERVICE_ROLE_KEY)",
        "SUPABASE_JWKS_URL=$($estado.API_URL)/auth/v1/.well-known/jwks.json",
        "SUPABASE_JWT_SECRET=$($estado.JWT_SECRET)",
        "CLAVE_CIFRADO=$(New-SecretoHex)",
        "SUNAT_GATEWAY_URL=http://127.0.0.1:$PuertoGateway",
        "SUNAT_GATEWAY_TOKEN=$(New-SecretoHex)",
        'SUNAT_DEMO_USUARIO=MODDATOS',
        'SUNAT_DEMO_CLAVE=moddatos',
        'CORS_ORIGENES='
    ) | Set-Content -Encoding ascii $rutaEnvApi
}

if (-not (Test-Path (Join-Path $rutaApi 'node_modules'))) {
    Push-Location $rutaApi
    cmd /c "npm ci >nul 2>&1"
    Pop-Location
}

$variables = @{}
foreach ($linea in Get-Content (Join-Path $rutaApi '.env')) {
    if ($linea -match '^([A-Z_]+)=(.*)$') { $variables[$Matches[1]] = $Matches[2].Trim('"') }
}
$demoUsuario = if ($variables['SUNAT_DEMO_USUARIO'] -and $variables['SUNAT_DEMO_USUARIO'] -ne 'definir-en-local') { $variables['SUNAT_DEMO_USUARIO'] } else { 'MODDATOS' }
$demoClave = if ($variables['SUNAT_DEMO_CLAVE'] -and $variables['SUNAT_DEMO_CLAVE'] -ne 'definir-en-local') { $variables['SUNAT_DEMO_CLAVE'] } else { 'moddatos' }

@{
    SUPABASE_URL      = $estado.API_URL
    SUPABASE_ANON_KEY = $estado.ANON_KEY
    API_URL           = "http://127.0.0.1:$PuertoApi"
} | ConvertTo-Json | Set-Content -Encoding ascii $rutaEnvMovil

cmd /c "docker rm -f facturador_gateway_local >nul 2>&1"
cmd /c "docker build -q -t sunat-gateway:local services/sunat-gateway >nul"
docker run -d --name facturador_gateway_local -p "127.0.0.1:${PuertoGateway}:4210" `
    -e "SUNAT_GATEWAY_TOKEN=$($variables['SUNAT_GATEWAY_TOKEN'])" `
    -e "SUNAT_DEMO_USUARIO=$demoUsuario" `
    -e "SUNAT_DEMO_CLAVE=$demoClave" sunat-gateway:local | Out-Null

if (Test-Path $adb) {
    foreach ($puerto in 54321, $PuertoApi) { & $adb reverse "tcp:$puerto" "tcp:$puerto" | Out-Null }
}

$env:PORT = "$PuertoApi"
$env:SUNAT_GATEWAY_URL = "http://127.0.0.1:$PuertoGateway"
$env:SUNAT_DEMO_USUARIO = $demoUsuario
$env:SUNAT_DEMO_CLAVE = $demoClave

$api = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'npx tsx src/server.ts' -WorkingDirectory $rutaApi -WindowStyle Minimized -PassThru
$worker = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', 'npx tsx src/worker.ts' -WorkingDirectory $rutaApi -WindowStyle Minimized -PassThru

Write-Output "API: http://127.0.0.1:$PuertoApi (PID $($api.Id)), worker PID $($worker.Id)"
Write-Output "Gateway: http://127.0.0.1:$PuertoGateway"
Write-Output "Studio de Supabase: $($estado.STUDIO_URL)"
