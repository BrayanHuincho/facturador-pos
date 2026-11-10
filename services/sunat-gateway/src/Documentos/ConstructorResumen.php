<?php

declare(strict_types=1);

namespace SunatGateway\Documentos;

use Greenter\Model\Sale\Document;
use Greenter\Model\Summary\Summary;
use Greenter\Model\Summary\SummaryDetail;
use InvalidArgumentException;
use SunatGateway\Sunat\SolicitudSunat;

final readonly class ConstructorResumen
{
    public function __construct(private SolicitudSunat $solicitud)
    {
    }

    public function construir(): Summary
    {
        $documento = $this->solicitud->documento;
        $detalles = array_map(
            fn (array $detalle): SummaryDetail => $this->detalle($detalle),
            array_values(array_map(static fn ($detalle): array => (array) $detalle, (array) ($documento['detalles'] ?? []))),
        );
        if (!$detalles) {
            throw new InvalidArgumentException('El resumen no tiene detalles');
        }

        return (new Summary())
            ->setFecGeneracion(Conversor::fecha($documento['fecha_referencia'] ?? null))
            ->setFecResumen(Conversor::fecha($documento['fecha_envio'] ?? null))
            ->setCorrelativo(Conversor::correlativoTresDigitos($documento))
            ->setMoneda((string) ($documento['moneda'] ?? 'PEN'))
            ->setCompany(Partes::empresa($this->solicitud->emisor))
            ->setDetails($detalles);
    }

    private function detalle(array $detalle): SummaryDetail
    {
        $resultado = (new SummaryDetail())
            ->setTipoDoc((string) $detalle['tipo_documento'])
            ->setSerieNro((string) $detalle['serie_numero'])
            ->setEstado((string) ($detalle['estado'] ?? '1'))
            ->setClienteTipo((string) ($detalle['cliente_tipo'] ?? '1'))
            ->setClienteNro((string) ($detalle['cliente_numero'] ?? '00000000'))
            ->setTotal(Conversor::numero($detalle['total'] ?? 0))
            ->setMtoOperGravadas(Conversor::numero($detalle['op_gravadas'] ?? 0))
            ->setMtoOperExoneradas(Conversor::numero($detalle['op_exoneradas'] ?? 0))
            ->setMtoOperInafectas(Conversor::numero($detalle['op_inafectas'] ?? 0))
            ->setMtoIGV(Conversor::numero($detalle['igv'] ?? 0))
            ->setPorcentajeIgv(Conversor::numero($detalle['porcentaje_igv'] ?? 18));
        if (Conversor::numero($detalle['op_exportacion'] ?? 0) > 0) {
            $resultado->setMtoOperExportacion(Conversor::numero($detalle['op_exportacion']));
        }
        if (Conversor::numero($detalle['op_gratuitas'] ?? 0) > 0) {
            $resultado->setMtoOperGratuitas(Conversor::numero($detalle['op_gratuitas']));
        }
        if (Conversor::numero($detalle['isc'] ?? 0) > 0) {
            $resultado->setMtoISC(Conversor::numero($detalle['isc']));
        }
        if (Conversor::numero($detalle['icbper'] ?? 0) > 0) {
            $resultado->setMtoIcbper(Conversor::numero($detalle['icbper']));
        }
        if (!empty($detalle['documento_referencia'])) {
            $referencia = (array) $detalle['documento_referencia'];
            $resultado->setDocReferencia((new Document())
                ->setTipoDoc((string) $referencia['tipo_documento'])
                ->setNroDoc((string) $referencia['numero_documento']));
        }

        return $resultado;
    }
}
