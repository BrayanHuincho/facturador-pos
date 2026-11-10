<?php

declare(strict_types=1);

namespace SunatGateway\Sunat;

use Greenter\See;
use Greenter\Ws\Services\SunatEndpoints;
use InvalidArgumentException;
use SunatGateway\Configuracion\Entorno;

final class FabricaSee
{
    public static function endpoint(SolicitudSunat $solicitud): string
    {
        $configurado = (string) ($solicitud->credenciales['endpoint'] ?? '');
        if ($configurado !== '') {
            return $configurado;
        }

        return $solicitud->esProduccion() ? SunatEndpoints::FE_PRODUCCION : SunatEndpoints::FE_BETA;
    }

    public static function crear(SolicitudSunat $solicitud): See
    {
        $see = new See();
        $see->setService(self::endpoint($solicitud));
        $solicitud->esProduccion() ? self::configurarProduccion($see, $solicitud) : self::configurarBeta($see, $solicitud);
        $see->setCachePath(sys_get_temp_dir() . '/greenter');

        return $see;
    }

    private static function configurarProduccion(See $see, SolicitudSunat $solicitud): void
    {
        $credenciales = $solicitud->credenciales;
        if (empty($credenciales['usuario_sol']) || empty($credenciales['clave_sol'])) {
            throw new InvalidArgumentException('Faltan el usuario y la clave SOL');
        }
        if (empty($credenciales['certificado'])) {
            throw new InvalidArgumentException('Falta el certificado digital');
        }
        $see->setClaveSOL($solicitud->ruc(), (string) $credenciales['usuario_sol'], (string) $credenciales['clave_sol']);
        $see->setCertificate(Certificado::normalizar((string) $credenciales['certificado'], $credenciales['certificado_clave'] ?? null));
    }

    private static function configurarBeta(See $see, SolicitudSunat $solicitud): void
    {
        $credenciales = $solicitud->credenciales;
        $usuario = (string) (($credenciales['usuario_sol'] ?? '') ?: Entorno::demoUsuario());
        $clave = (string) (($credenciales['clave_sol'] ?? '') ?: Entorno::demoClave());
        if ($usuario === '' || $clave === '') {
            throw new InvalidArgumentException('Faltan las credenciales demo: envía usuario_sol y clave_sol o define SUNAT_DEMO_USUARIO y SUNAT_DEMO_CLAVE');
        }
        $see->setClaveSOL($solicitud->ruc(), $usuario, $clave);
        $see->setCertificate(Certificado::deSolicitudOPrueba($credenciales));
    }
}
