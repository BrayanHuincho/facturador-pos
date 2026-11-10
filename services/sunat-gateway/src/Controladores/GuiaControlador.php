<?php

declare(strict_types=1);

namespace SunatGateway\Controladores;

use SunatGateway\Sunat\ServicioGuias;
use SunatGateway\Sunat\SolicitudSunat;

final class GuiaControlador extends ControladorSunat
{
    protected function procesar(SolicitudSunat $solicitud): array
    {
        return (new ServicioGuias($solicitud))->enviar();
    }
}
