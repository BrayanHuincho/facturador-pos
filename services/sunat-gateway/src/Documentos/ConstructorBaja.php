<?php

declare(strict_types=1);

namespace SunatGateway\Documentos;

use Greenter\Model\Voided\Voided;
use Greenter\Model\Voided\VoidedDetail;
use InvalidArgumentException;
use SunatGateway\Sunat\SolicitudSunat;

final readonly class ConstructorBaja
{
    public function __construct(private SolicitudSunat $solicitud)
    {
    }

    public function construir(): Voided
    {
        $documento = $this->solicitud->documento;
        $detalles = array_map(
            static fn (array $detalle): VoidedDetail => (new VoidedDetail())
                ->setTipoDoc((string) $detalle['tipo_documento'])
                ->setSerie((string) $detalle['serie'])
                ->setCorrelativo((string) $detalle['correlativo'])
                ->setDesMotivoBaja(mb_substr((string) ($detalle['motivo'] ?? 'ERROR EN EL COMPROBANTE'), 0, 100)),
            array_values(array_map(static fn ($detalle): array => (array) $detalle, (array) ($documento['detalles'] ?? []))),
        );
        if (!$detalles) {
            throw new InvalidArgumentException('La baja no tiene detalles');
        }

        return (new Voided())
            ->setCorrelativo(Conversor::correlativoTresDigitos($documento))
            ->setFecGeneracion(Conversor::fecha($documento['fecha_referencia'] ?? null))
            ->setFecComunicacion(Conversor::fecha($documento['fecha_envio'] ?? null))
            ->setCompany(Partes::empresa($this->solicitud->emisor))
            ->setDetails($detalles);
    }
}
