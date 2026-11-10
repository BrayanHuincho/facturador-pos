<?php

declare(strict_types=1);

namespace SunatGateway\Controladores;

use SunatGateway\Http\Respuesta;

interface Controlador
{
    public function __invoke(array $datos): Respuesta;
}
