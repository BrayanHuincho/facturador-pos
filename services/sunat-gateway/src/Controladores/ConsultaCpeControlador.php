<?php

declare(strict_types=1);

namespace SunatGateway\Controladores;

use SunatGateway\Sunat\ServicioConsultaCpe;
use SunatGateway\Sunat\SolicitudSunat;

final class ConsultaCpeControlador extends ControladorSunat
{
    protected function procesar(SolicitudSunat $solicitud): array
    {
        return (new ServicioConsultaCpe($solicitud))->consultar();
    }
}
