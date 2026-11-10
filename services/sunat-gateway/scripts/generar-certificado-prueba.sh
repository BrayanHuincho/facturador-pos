#!/bin/sh
set -eu

raiz="$(cd "$(dirname "$0")/.." && pwd)"
destino="${CERTIFICADO_PRUEBA_RUTA:-$raiz/certificados/certificado-prueba.pem}"

if [ -s "$destino" ] && [ "${1:-}" != "--forzar" ]; then
    echo "Ya existe el certificado de prueba: $destino"
    exit 0
fi

umask 077
mkdir -p "$(dirname "$destino")"
temporal="$(mktemp -d)"
trap 'rm -rf "$temporal"' EXIT

cat > "$temporal/certificado.cnf" <<CONFIG
[req]
prompt = no
distinguished_name = dn
x509_extensions = ext

[dn]
C = PE
O = Facturador POS Pruebas
CN = Certificado de prueba Facturador

[ext]
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, nonRepudiation
CONFIG

openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 3650 \
    -config "$temporal/certificado.cnf" \
    -keyout "$temporal/clave.pem" \
    -out "$temporal/certificado.pem" 2>/dev/null

cat "$temporal/clave.pem" "$temporal/certificado.pem" > "$destino"
chmod 600 "$destino"
echo "Certificado de prueba generado: $destino"
