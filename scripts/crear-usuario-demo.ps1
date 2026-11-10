$ErrorActionPreference = 'Stop'
$raiz = Split-Path -Parent $PSScriptRoot
Set-Location $raiz

$correo = 'demo@gmail.com'
$acceso = 'demo12345'

$estado = cmd /c "npx supabase status -o json 2>nul" | Out-String | ConvertFrom-Json
$cabeceras = @{ apikey = $estado.SERVICE_ROLE_KEY; Authorization = "Bearer $($estado.SERVICE_ROLE_KEY)" }

$usuarios = (Invoke-RestMethod -Uri "$($estado.API_URL)/auth/v1/admin/users" -Headers $cabeceras).users
if ($usuarios | Where-Object email -eq $correo) {
    Write-Output "El usuario $correo ya existe."
    exit 0
}

$cuerpo = @{ email = $correo; password = $acceso; email_confirm = $true } | ConvertTo-Json
Invoke-RestMethod -Uri "$($estado.API_URL)/auth/v1/admin/users" -Method Post -ContentType 'application/json' -Headers $cabeceras -Body $cuerpo | Out-Null
Write-Output "Usuario creado: $correo / $acceso"
