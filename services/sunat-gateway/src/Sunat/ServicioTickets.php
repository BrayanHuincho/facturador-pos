<?php

declare(strict_types=1);

namespace SunatGateway\Sunat;

use Greenter\Model\DocumentInterface;
use InvalidArgumentException;
use SunatGateway\Documentos\ConstructorBaja;
use SunatGateway\Documentos\ConstructorResumen;

final class ServicioTickets
{
    public function __construct(private readonly SolicitudSunat $solicitud)
    {
    }

    public function enviarResumen(): array
    {
        return $this->enviar((new ConstructorResumen($this->solicitud))->construir());
    }

    public function enviarBaja(): array
    {
        return $this->enviar((new ConstructorBaja($this->solicitud))->construir());
    }

    public function consultarTicket(): array
    {
        $ticket = (string) ($this->solicitud->documento['ticket'] ?? '');
        if ($ticket === '') {
            throw new InvalidArgumentException('Falta documento.ticket');
        }
        $resultado = FabricaSee::crear($this->solicitud)->getStatus($ticket);
        $extra = ['ticket' => $ticket, 'estado_ticket' => $resultado->getCode()];
        $cdr = $resultado->getCdrResponse();
        if ($resultado->isSuccess() && $cdr !== null) {
            return FormatoRespuesta::comprobante(true, null, $cdr, $resultado->getCdrZip(), null) + $extra;
        }

        return FormatoRespuesta::comprobante(false, null, null, null, $resultado->getError()) + $extra;
    }

    private function enviar(DocumentInterface $documento): array
    {
        $see = FabricaSee::crear($this->solicitud);
        $resultado = $see->send($documento);
        $xml = $see->getFactory()->getLastXml();
        $exito = $resultado->isSuccess();

        return FormatoRespuesta::comprobante($exito, $xml, null, null, $exito ? null : $resultado->getError()) + [
            'ticket' => $exito ? $resultado->getTicket() : null,
            'nombre' => $documento->getName(),
        ];
    }
}
