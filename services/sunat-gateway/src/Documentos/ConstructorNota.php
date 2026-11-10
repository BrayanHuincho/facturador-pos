<?php

declare(strict_types=1);

namespace SunatGateway\Documentos;

use Greenter\Model\Sale\FormaPagos\FormaPagoCredito;
use Greenter\Model\Sale\Note;
use InvalidArgumentException;
use SunatGateway\Sunat\SolicitudSunat;

final readonly class ConstructorNota
{
    public function __construct(private SolicitudSunat $solicitud)
    {
    }

    public function construir(): Note
    {
        $documento = $this->solicitud->documento;
        $tipo = (string) ($documento['tipo_documento'] ?? '');
        if (!in_array($tipo, ['07', '08'], true)) {
            throw new InvalidArgumentException('tipo_documento debe ser 07 u 08');
        }
        foreach (['tipo_doc_afectado', 'num_doc_afectado', 'cod_motivo', 'des_motivo'] as $campo) {
            if (empty($documento[$campo])) {
                throw new InvalidArgumentException("Falta documento.{$campo}");
            }
        }
        $totales = (array) ($documento['totales'] ?? []);
        $moneda = (string) ($documento['moneda'] ?? 'PEN');

        $nota = (new Note())
            ->setUblVersion('2.1')
            ->setTipoDoc($tipo)
            ->setSerie((string) $documento['serie'])
            ->setCorrelativo((string) $documento['correlativo'])
            ->setFechaEmision(Conversor::fecha($documento['fecha_emision'] ?? null, $documento['hora_emision'] ?? null))
            ->setTipDocAfectado((string) $documento['tipo_doc_afectado'])
            ->setNumDocfectado((string) $documento['num_doc_afectado'])
            ->setCodMotivo((string) $documento['cod_motivo'])
            ->setDesMotivo(mb_substr((string) $documento['des_motivo'], 0, 250))
            ->setTipoMoneda($moneda)
            ->setCompany(Partes::empresa($this->solicitud->emisor))
            ->setClient(Partes::cliente((array) ($documento['cliente'] ?? [])));

        if (strtoupper((string) ($documento['forma_pago'] ?? '')) === 'CREDITO' && !empty($documento['cuotas'])) {
            $nota->setFormaPago(new FormaPagoCredito(Conversor::numero($totales['total'] ?? 0), $moneda));
            $nota->setCuotas(Partes::cuotas((array) $documento['cuotas'], $moneda));
        }
        if ($moneda !== 'PEN') {
            $nota->setTipoCambio(Conversor::numero($documento['tipo_cambio'] ?? 1));
        }

        $this->aplicarTotales($nota, $totales);
        $nota->setDetails(Partes::detalles((array) ($documento['items'] ?? []), false));
        $nota->setLegends(Partes::leyendas((array) ($documento['leyendas'] ?? [])));

        return $nota;
    }

    private function aplicarTotales(Note $nota, array $totales): void
    {
        $nota->setMtoOperGravadas(Conversor::numero($totales['op_gravadas'] ?? 0))
            ->setMtoOperExoneradas(Conversor::numero($totales['op_exoneradas'] ?? 0))
            ->setMtoOperInafectas(Conversor::numero($totales['op_inafectas'] ?? 0))
            ->setMtoIGV(Conversor::numero($totales['igv'] ?? 0))
            ->setTotalImpuestos(Partes::totalImpuestos($totales))
            ->setValorVenta(Conversor::numero($totales['valor_venta'] ?? 0))
            ->setMtoImpVenta(Conversor::numero($totales['total'] ?? 0));
        if (Conversor::numero($totales['op_exportacion'] ?? 0) > 0) {
            $nota->setMtoOperExportacion(Conversor::numero($totales['op_exportacion']));
        }
        if (Conversor::numero($totales['op_gratuitas'] ?? 0) > 0) {
            $nota->setMtoOperGratuitas(Conversor::numero($totales['op_gratuitas']));
        }
        if (Conversor::numero($totales['isc'] ?? 0) > 0) {
            $nota->setMtoISC(Conversor::numero($totales['isc']));
        }
        if (Conversor::numero($totales['icbper'] ?? 0) > 0) {
            $nota->setIcbper(Conversor::numero($totales['icbper']));
        }
    }
}
