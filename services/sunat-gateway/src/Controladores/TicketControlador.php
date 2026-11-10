<?php

declare(strict_types=1);

namespace SunatGateway\Controladores;

use SunatGateway\Sunat\ServicioTickets;
use SunatGateway\Sunat\SolicitudSunat;

final class TicketControlador extends ControladorSunat
{
    protected function procesar(SolicitudSunat $solicitud): array
    {
        return (new ServicioTickets($solicitud))->consultarTicket();
    }
}
