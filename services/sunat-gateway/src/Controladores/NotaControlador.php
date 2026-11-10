<?php

declare(strict_types=1);

namespace SunatGateway\Controladores;

use SunatGateway\Sunat\ServicioComprobantes;
use SunatGateway\Sunat\SolicitudSunat;

final class NotaControlador extends ControladorSunat
{
    protected function procesar(SolicitudSunat $solicitud): array
    {
        return (new ServicioComprobantes($solicitud))->enviarNota();
    }
}
