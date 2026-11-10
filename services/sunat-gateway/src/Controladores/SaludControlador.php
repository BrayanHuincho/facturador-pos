<?php

declare(strict_types=1);

namespace SunatGateway\Controladores;

use SunatGateway\Http\Respuesta;

final class SaludControlador implements Controlador
{
    public function __invoke(array $datos): Respuesta
    {
        return Respuesta::json(200, [
            'ok' => true,
            'servicio' => 'servicio-sunat',
            'php' => PHP_VERSION,
            'soap' => extension_loaded('soap'),
            'zip' => extension_loaded('zip'),
            'openssl' => extension_loaded('openssl'),
            'hora' => date('c'),
        ]);
    }
}
