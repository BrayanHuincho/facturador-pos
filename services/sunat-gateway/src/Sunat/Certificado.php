<?php

declare(strict_types=1);

namespace SunatGateway\Sunat;

use InvalidArgumentException;
use SunatGateway\Configuracion\Entorno;

final class Certificado
{
    public static function normalizar(#[\SensitiveParameter] string $pem, #[\SensitiveParameter] ?string $clave): string
    {
        $pem = str_replace(["\r\n", "\r"], "\n", trim($pem));
        if ($clave && str_contains($pem, 'ENCRYPTED PRIVATE KEY')) {
            $llave = openssl_pkey_get_private($pem, $clave);
            if ($llave === false) {
                throw new InvalidArgumentException('No se pudo descifrar la clave privada del certificado');
            }
            openssl_pkey_export($llave, $exportada);
            $bloqueCifrado = 'ENCRYPTED PRIVATE KEY';
            $pem = preg_replace('/-----BEGIN ' . $bloqueCifrado . '-----.*?-----END ' . $bloqueCifrado . '-----/s', $exportada, $pem) ?? $pem;
        }
        $salida = [];
        foreach (['PRIVATE KEY', 'RSA PRIVATE KEY', 'CERTIFICATE'] as $bloque) {
            if (preg_match('/-----BEGIN ' . $bloque . '-----(.*?)-----END ' . $bloque . '-----/s', $pem, $m)) {
                $salida[] = "-----BEGIN {$bloque}-----\n" . rtrim(chunk_split(preg_replace('/\s+/', '', $m[1]) ?? '', 64, "\n")) . "\n-----END {$bloque}-----";
            }
        }
        $unido = implode('', $salida);
        if (!str_contains($unido, 'PRIVATE KEY-----') || !str_contains($unido, 'BEGIN CERTIFICATE')) {
            throw new InvalidArgumentException('El certificado PEM debe traer la clave privada y el certificado');
        }

        return implode("\n", $salida) . "\n";
    }

    public static function deSolicitudOPrueba(#[\SensitiveParameter] array $credenciales): string
    {
        if (!empty($credenciales['certificado'])) {
            return self::normalizar((string) $credenciales['certificado'], $credenciales['certificado_clave'] ?? null);
        }
        $ruta = Entorno::rutaCertificadoPrueba();
        $pem = is_readable($ruta) ? file_get_contents($ruta) : false;
        if ($pem === false || $pem === '') {
            throw new InvalidArgumentException('Falta el certificado de prueba: ejecuta scripts/generar-certificado-prueba.sh o envía credenciales.certificado');
        }

        return $pem;
    }
}
