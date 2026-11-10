<?php

declare(strict_types=1);

namespace SunatGateway\Documentos;

use Greenter\Model\Client\Client;
use Greenter\Model\Company\Address;
use Greenter\Model\Company\Company;
use Greenter\Model\Sale\Charge;
use Greenter\Model\Sale\Cuota;
use Greenter\Model\Sale\Legend;
use Greenter\Model\Sale\SaleDetail;
use InvalidArgumentException;

final class Partes
{
    private const TIPOS_DOCUMENTO_CLIENTE = ['0', '1', '4', '6', '7'];
    private const FACTOR_ICBPER = 0.5;

    public static function empresa(array $emisor): Company
    {
        $direccion = self::direccionEmisor($emisor)
            ->setUrbanizacion('-')
            ->setCodLocal((string) (($emisor['cod_local'] ?? '') ?: '0000'));

        return (new Company())
            ->setRuc((string) $emisor['ruc'])
            ->setRazonSocial((string) $emisor['razon_social'])
            ->setNombreComercial((string) (($emisor['nombre_comercial'] ?? '') ?: $emisor['razon_social']))
            ->setAddress($direccion);
    }

    public static function empresaDeGuia(array $emisor): Company
    {
        return (new Company())
            ->setRuc((string) $emisor['ruc'])
            ->setRazonSocial((string) ($emisor['razon_social'] ?? ''))
            ->setNombreComercial((string) (($emisor['nombre_comercial'] ?? '') ?: ($emisor['razon_social'] ?? '')))
            ->setAddress(self::direccionEmisor($emisor));
    }

    public static function cliente(array $cliente): Client
    {
        $tipo = (string) ($cliente['tipo_documento'] ?? '0');
        if (!in_array($tipo, self::TIPOS_DOCUMENTO_CLIENTE, true)) {
            throw new InvalidArgumentException("Tipo de documento del cliente no válido: {$tipo}");
        }
        $numero = (string) ($cliente['numero_documento'] ?? '');
        if ($numero === '') {
            $numero = $tipo === '0' ? '00000000' : '-';
        }
        $resultado = (new Client())
            ->setTipoDoc($tipo)
            ->setNumDoc($numero)
            ->setRznSocial(mb_substr((string) (($cliente['razon_social'] ?? '') ?: 'CLIENTES VARIOS'), 0, 250));
        if (!empty($cliente['direccion'])) {
            $direccion = (new Address())->setDireccion((string) $cliente['direccion']);
            if (!empty($cliente['ubigeo'])) {
                $direccion->setUbigueo((string) $cliente['ubigeo']);
            }
            $resultado->setAddress($direccion);
        }

        return $resultado;
    }

    public static function leyendas(array $leyendas): array
    {
        $resultado = [];
        foreach ($leyendas as $leyenda) {
            $codigo = (string) ($leyenda['codigo'] ?? $leyenda['code'] ?? '');
            $valor = (string) ($leyenda['valor'] ?? $leyenda['value'] ?? '');
            if ($codigo !== '' && $valor !== '') {
                $resultado[] = (new Legend())->setCode($codigo)->setValue($valor);
            }
        }

        return $resultado;
    }

    public static function cuotas(array $cuotas, string $moneda): array
    {
        return array_map(
            static fn (array $cuota): Cuota => (new Cuota())
                ->setMoneda($moneda)
                ->setMonto(Conversor::numero($cuota['monto']))
                ->setFechaPago(Conversor::fecha($cuota['fecha_pago'])),
            array_values(array_map(static fn ($cuota): array => (array) $cuota, $cuotas)),
        );
    }

    public static function totalImpuestos(array $importes): float
    {
        if (isset($importes['total_impuestos'])) {
            return Conversor::numero($importes['total_impuestos']);
        }

        return Conversor::numero(
            Conversor::numero($importes['igv'] ?? 0)
            + Conversor::numero($importes['isc'] ?? 0)
            + Conversor::numero($importes['icbper'] ?? 0),
        );
    }

    public static function detalles(array $items, bool $conDescuentos = true): array
    {
        if (!$items) {
            throw new InvalidArgumentException('El comprobante no tiene ítems');
        }

        return array_map(
            static fn (array $item): SaleDetail => self::detalle($item, $conDescuentos),
            array_values(array_map(static fn ($item): array => (array) $item, $items)),
        );
    }

    private static function detalle(array $item, bool $conDescuentos): SaleDetail
    {
        $tipo = (string) ($item['tipo_afectacion_igv'] ?? '10');
        $gratuito = (bool) preg_match('/^(1[1-7]|21|3[1-7])$/', $tipo);
        $detalle = (new SaleDetail())
            ->setCodProducto(mb_substr((string) (($item['codigo'] ?? '') !== '' ? $item['codigo'] : '-'), 0, 30))
            ->setUnidad((string) ($item['unidad'] ?? 'NIU'))
            ->setDescripcion(mb_substr((string) $item['descripcion'], 0, 500))
            ->setCantidad(Conversor::numero($item['cantidad']))
            ->setMtoValorVenta(Conversor::numero($item['valor_venta']))
            ->setMtoBaseIgv(Conversor::numero($item['base_igv'] ?? $item['valor_venta']))
            ->setPorcentajeIgv(Conversor::numero($item['porcentaje_igv'] ?? 0))
            ->setIgv(Conversor::numero($item['igv'] ?? 0))
            ->setTipAfeIgv($tipo)
            ->setTotalImpuestos(self::totalImpuestos($item));

        if ($gratuito) {
            $detalle->setMtoValorUnitario(0)
                ->setMtoValorGratuito(Conversor::numero($item['valor_unitario']))
                ->setMtoPrecioUnitario(0);
        } else {
            $detalle->setMtoValorUnitario(Conversor::numero($item['valor_unitario']))
                ->setMtoPrecioUnitario(Conversor::numero($item['precio_unitario']));
        }
        if ($conDescuentos && !$gratuito) {
            self::aplicarDescuento($detalle, (array) ($item['descuento'] ?? []));
        }
        if (Conversor::numero($item['isc'] ?? 0) > 0) {
            $detalle->setIsc(Conversor::numero($item['isc']))
                ->setTipSisIsc((string) ($item['tip_sis_isc'] ?? '01'))
                ->setMtoBaseIsc(Conversor::numero($item['valor_venta']));
        }
        if (Conversor::numero($item['icbper'] ?? 0) > 0) {
            $detalle->setIcbper(Conversor::numero($item['icbper']))
                ->setFactorIcbper(Conversor::numero($item['factor_icbper'] ?? self::FACTOR_ICBPER));
        }

        return $detalle;
    }

    private static function aplicarDescuento(SaleDetail $detalle, array $descuento): void
    {
        if (Conversor::numero($descuento['monto'] ?? 0) <= 0) {
            return;
        }
        $detalle->setDescuentos([(new Charge())
            ->setCodTipo('00')
            ->setFactor(round(Conversor::numero($descuento['factor'] ?? 0), 5))
            ->setMonto(round(Conversor::numero($descuento['monto']), 2))
            ->setMontoBase(round(Conversor::numero($descuento['base'] ?? 0), 2))]);
    }

    private static function direccionEmisor(array $emisor): Address
    {
        return (new Address())
            ->setUbigueo((string) (($emisor['ubigeo'] ?? '') ?: '150101'))
            ->setDepartamento((string) (($emisor['departamento'] ?? '') ?: 'LIMA'))
            ->setProvincia((string) (($emisor['provincia'] ?? '') ?: 'LIMA'))
            ->setDistrito((string) (($emisor['distrito'] ?? '') ?: 'LIMA'))
            ->setDireccion((string) (($emisor['direccion'] ?? '') ?: '-'));
    }
}
