<?php

declare(strict_types=1);

namespace SunatGateway\Controladores;

use SunatGateway\Http\Respuesta;
use SunatGateway\Sunat\SolicitudSunat;

abstract class ControladorSunat implements Controlador
{
    final public function __invoke(array $datos): Respuesta
    {
        return Respuesta::json(200, $this->procesar(new SolicitudSunat($datos)));
    }

    abstract protected function procesar(SolicitudSunat $solicitud): array;
}
