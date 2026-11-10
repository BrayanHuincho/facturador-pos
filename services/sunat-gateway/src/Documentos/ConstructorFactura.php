<?php

declare(strict_types=1);

namespace SunatGateway\Documentos;

use Greenter\Model\Sale\Detraction;
use Greenter\Model\Sale\Document;
use Greenter\Model\Sale\FormaPagos\FormaPagoContado;
use Greenter\Model\Sale\FormaPagos\FormaPagoCredito;
use Greenter\Model\Sale\Invoice;
use InvalidArgumentException;
use SunatGateway\Sunat\SolicitudSunat;

final readonly class ConstructorFactura
{
    private const TIPO_BOLETA = '03';
    private const OPERACION_EXPORTACION = '0200';

    private array $documento;
    private array $totales;
    private string $moneda;

    public function __construct(private SolicitudSunat $solicitud)
    {
        $this->documento = $solicitud->documento;
        $this->totales = (array) ($this->documento['totales'] ?? []);
        $this->moneda = (string) ($this->documento['moneda'] ?? 'PEN');
    }

    public function construir(): Invoice
    {
        $documento = $this->documento;
        $tipo = (string) ($documento['tipo_documento'] ?? '');
        if (!in_array($tipo, ['01', self::TIPO_BOLETA], true)) {
            throw new InvalidArgumentException('tipo_documento debe ser 01 o 03');
        }

        $factura = (new Invoice())
            ->setUblVersion('2.1')
            ->setTipoOperacion((string) ($documento['tipo_operacion'] ?? '0101'))
            ->setTipoDoc($tipo)
            ->setSerie((string) $documento['serie'])
            ->setCorrelativo((string) $documento['correlativo'])
            ->setFechaEmision(Conversor::fecha($documento['fecha_emision'] ?? null, $documento['hora_emision'] ?? null))
            ->setTipoMoneda($this->moneda)
            ->setCompany(Partes::empresa($this->solicitud->emisor))
            ->setClient(Partes::cliente((array) ($documento['cliente'] ?? [])));

        if ($this->moneda !== 'PEN') {
            $factura->setTipoCambio(Conversor::numero($documento['tipo_cambio'] ?? 1));
        }
        if (!empty($documento['fecha_vencimiento'])) {
            $factura->setFecVencimiento(Conversor::fecha($documento['fecha_vencimiento']));
        }
        if (!empty($documento['orden_compra'])) {
            $factura->setCompra(mb_substr((string) $documento['orden_compra'], 0, 20));
        }

        $this->aplicarFormaPago($factura, $tipo);
        $this->aplicarDetraccion($factura);
        $this->aplicarObservacion($factura);
        $this->aplicarTotales($factura);
        $this->aplicarGuias($factura);

        $factura->setDetails(Partes::detalles((array) ($documento['items'] ?? [])));
        $factura->setLegends(Partes::leyendas((array) ($documento['leyendas'] ?? [])));

        return $factura;
    }

    private function aplicarFormaPago(Invoice $factura, string $tipo): void
    {
        $credito = strtoupper((string) ($this->documento['forma_pago'] ?? 'CONTADO')) === 'CREDITO';
        if ($credito && $tipo === self::TIPO_BOLETA) {
            return;
        }
        if (!$credito) {
            $factura->setFormaPago(new FormaPagoContado());

            return;
        }
        $factura->setFormaPago(new FormaPagoCredito(round($this->montoPendiente(), 2), $this->moneda));
        $cuotas = Partes::cuotas((array) ($this->documento['cuotas'] ?? []), $this->moneda);
        if (!$cuotas) {
            throw new InvalidArgumentException('Una venta al crédito necesita al menos una cuota');
        }
        $factura->setCuotas($cuotas);
    }

    private function montoPendiente(): float
    {
        if (isset($this->documento['monto_pendiente'])) {
            return Conversor::numero($this->documento['monto_pendiente']);
        }
        $detraccion = !empty($this->documento['detraccion'])
            ? Conversor::numero(((array) $this->documento['detraccion'])['monto'] ?? 0)
            : 0.0;

        return Conversor::numero($this->totales['total'] ?? 0) - $detraccion;
    }

    private function aplicarDetraccion(Invoice $factura): void
    {
        if (empty($this->documento['detraccion'])) {
            return;
        }
        $detraccion = (array) $this->documento['detraccion'];
        $factura->setDetraccion((new Detraction())
            ->setCodBienDetraccion((string) $detraccion['codigo_bien_servicio'])
            ->setCodMedioPago((string) ($detraccion['codigo_medio_pago'] ?? '001'))
            ->setCtaBanco((string) ($detraccion['cuenta_banco'] ?? ''))
            ->setPercent(Conversor::numero($detraccion['porcentaje']))
            ->setMount(Conversor::numero($detraccion['monto'] ?? 0)));
    }

    private function aplicarObservacion(Invoice $factura): void
    {
        $observacion = trim((string) preg_replace('/\s+/u', ' ', (string) ($this->documento['observaciones'] ?? '')));
        if ($observacion !== '') {
            $factura->setObservacion(mb_substr($observacion, 0, 200));
        }
    }

    private function aplicarTotales(Invoice $factura): void
    {
        $totales = $this->totales;
        if (($this->documento['tipo_operacion'] ?? '0101') === self::OPERACION_EXPORTACION) {
            $factura->setMtoOperExportacion(Conversor::numero($totales['op_exportacion'] ?? $totales['valor_venta'] ?? 0));
        } else {
            $factura->setMtoOperGravadas(Conversor::numero($totales['op_gravadas'] ?? 0))
                ->setMtoOperExoneradas(Conversor::numero($totales['op_exoneradas'] ?? 0))
                ->setMtoOperInafectas(Conversor::numero($totales['op_inafectas'] ?? 0));
            if (Conversor::numero($totales['op_exportacion'] ?? 0) > 0) {
                $factura->setMtoOperExportacion(Conversor::numero($totales['op_exportacion']));
            }
        }
        if (Conversor::numero($totales['op_gratuitas'] ?? 0) > 0) {
            $factura->setMtoOperGratuitas(Conversor::numero($totales['op_gratuitas']))
                ->setMtoIGVGratuitas(Conversor::numero($totales['igv_gratuitas'] ?? 0));
        }
        $factura->setMtoIGV(Conversor::numero($totales['igv'] ?? 0))
            ->setTotalImpuestos(Partes::totalImpuestos($totales))
            ->setValorVenta(Conversor::numero($totales['valor_venta'] ?? 0))
            ->setSubTotal(Conversor::numero($totales['sub_total'] ?? $totales['total'] ?? 0))
            ->setMtoImpVenta(Conversor::numero($totales['total'] ?? 0));
        if (Conversor::numero($totales['isc'] ?? 0) > 0) {
            $factura->setMtoISC(Conversor::numero($totales['isc']));
        }
        if (Conversor::numero($totales['icbper'] ?? 0) > 0) {
            $factura->setIcbper(Conversor::numero($totales['icbper']));
        }
    }

    private function aplicarGuias(Invoice $factura): void
    {
        if (empty($this->documento['guias'])) {
            return;
        }
        $factura->setGuias(array_map(
            static fn ($guia): Document => (new Document())
                ->setTipoDoc((string) (((array) $guia)['tipo'] ?? '09'))
                ->setNroDoc((string) (((array) $guia)['numero'] ?? '')),
            array_values((array) $this->documento['guias']),
        ));
    }
}
