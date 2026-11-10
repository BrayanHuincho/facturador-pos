<?php

declare(strict_types=1);

namespace SunatGateway\Configuracion;

final class Entorno
{
    public static function tokenInterno(): string
    {
        return self::valor('SUNAT_GATEWAY_TOKEN') ?: self::valor('SERVICIO_SUNAT_TOKEN');
    }

    public static function demoUsuario(): string
    {
        return self::valor('SUNAT_DEMO_USUARIO');
    }

    public static function demoClave(): string
    {
        return self::valor('SUNAT_DEMO_CLAVE');
    }

    public static function greBetaClientId(): string
    {
        return self::valor('GRE_BETA_CLIENT_ID');
    }

    public static function greBetaClientSecret(): string
    {
        return self::valor('GRE_BETA_CLIENT_SECRET');
    }

    public static function greBetaClave(): string
    {
        return self::valor('GRE_BETA_CLAVE') ?: self::demoClave();
    }

    public static function rutaCertificadoPrueba(): string
    {
        return self::valor('CERTIFICADO_PRUEBA_RUTA') ?: dirname(__DIR__, 2) . '/certificados/certificado-prueba.pem';
    }

    private static function valor(string $nombre): string
    {
        $valor = getenv($nombre);

        return is_string($valor) ? $valor : '';
    }
}
