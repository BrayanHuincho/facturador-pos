<?php

declare(strict_types=1);

namespace SunatGateway\Documentos;

use Greenter\Model\Client\Client;
use Greenter\Model\Despatch\AdditionalDoc;
use Greenter\Model\Despatch\Despatch;
use Greenter\Model\Despatch\DespatchDetail;
use Greenter\Model\Despatch\Direction;
use Greenter\Model\Despatch\Driver;
use Greenter\Model\Despatch\Shipment;
use Greenter\Model\Despatch\Transportist;
use Greenter\Model\Despatch\Vehicle;
use InvalidArgumentException;
use SunatGateway\Sunat\SolicitudSunat;

final readonly class ConstructorGuia
{
    private const CAMPOS_OBLIGATORIOS = ['serie', 'correlativo', 'motivo', 'modalidad', 'fecha_traslado', 'destinatario', 'partida', 'llegada', 'items'];
    private const MODALIDAD_PUBLICA = '01';

    private array $documento;

    public function __construct(private SolicitudSunat $solicitud)
    {
        $this->documento = $solicitud->documento;
    }

    public function construir(): Despatch
    {
        $documento = $this->documento;
        foreach (self::CAMPOS_OBLIGATORIOS as $campo) {
            if (empty($documento[$campo])) {
                throw new InvalidArgumentException("Falta documento.{$campo}");
            }
        }
        $destinatario = (array) $documento['destinatario'];

        $guia = (new Despatch())
            ->setVersion('2022')
            ->setTipoDoc('09')
            ->setSerie((string) $documento['serie'])
            ->setCorrelativo((string) $documento['correlativo'])
            ->setFechaEmision(Conversor::fechaGuia((string) ($documento['fecha_emision'] ?? 'now'), (string) ($documento['hora_emision'] ?? '')))
            ->setCompany(Partes::empresaDeGuia($this->solicitud->emisor))
            ->setDestinatario((new Client())
                ->setTipoDoc((string) $destinatario['tipo_documento'])
                ->setNumDoc((string) $destinatario['numero'])
                ->setRznSocial((string) $destinatario['razon_social']))
            ->setEnvio($this->envio())
            ->setDetails($this->detalles());

        if (!empty($documento['observaciones'])) {
            $guia->setObservacion(mb_substr((string) $documento['observaciones'], 0, 250));
        }
        if (!empty($documento['documento']['numero'])) {
            $relacionado = (array) $documento['documento'];
            $guia->setAddDocs([(new AdditionalDoc())
                ->setTipo((string) ($relacionado['tipo'] ?? '01'))
                ->setTipoDesc((string) ($relacionado['descripcion'] ?? 'Factura'))
                ->setNro((string) $relacionado['numero'])
                ->setEmisor($this->solicitud->ruc())]);
        }

        return $guia;
    }

    private function envio(): Shipment
    {
        $documento = $this->documento;
        $partida = (array) $documento['partida'];
        $llegada = (array) $documento['llegada'];

        $envio = (new Shipment())
            ->setCodTraslado((string) $documento['motivo'])
            ->setModTraslado((string) $documento['modalidad'])
            ->setFecTraslado(Conversor::fechaGuia((string) $documento['fecha_traslado']))
            ->setPesoTotal((float) ($documento['peso_total'] ?? 0))
            ->setUndPesoTotal((string) ($documento['unidad_peso'] ?? 'KGM'))
            ->setPartida((new Direction((string) $partida['ubigeo'], (string) $partida['direccion']))
                ->setRuc($this->solicitud->ruc())
                ->setCodLocal((string) ($partida['cod_local'] ?? '0000')))
            ->setLlegada(new Direction((string) $llegada['ubigeo'], (string) $llegada['direccion']));
        if (!empty($documento['motivo_descripcion'])) {
            $envio->setDesTraslado((string) $documento['motivo_descripcion']);
        }
        if (!empty($documento['bultos'])) {
            $envio->setNumBultos((int) $documento['bultos']);
        }

        if ((string) $documento['modalidad'] === self::MODALIDAD_PUBLICA) {
            $this->aplicarTransportePublico($envio);
        } elseif (!empty($documento['vehiculo_m1l'])) {
            $envio->setIndicadores(['SUNAT_Envio_IndicadorTrasladoVehiculoM1L']);
        } else {
            $this->aplicarTransportePrivado($envio);
        }

        return $envio;
    }

    private function aplicarTransportePublico(Shipment $envio): void
    {
        $datos = (array) ($this->documento['transportista'] ?? []);
        if (empty($datos['ruc']) || empty($datos['razon_social'])) {
            throw new InvalidArgumentException('Transporte público: falta el RUC y la razón social del transportista');
        }
        $transportista = (new Transportist())
            ->setTipoDoc('6')
            ->setNumDoc((string) $datos['ruc'])
            ->setRznSocial((string) $datos['razon_social']);
        if (!empty($datos['mtc'])) {
            $transportista->setNroMtc((string) $datos['mtc']);
        }
        $envio->setTransportista($transportista);
        $envio->setFecEntregaBienes(Conversor::fechaGuia((string) $this->documento['fecha_traslado']));
    }

    private function aplicarTransportePrivado(Shipment $envio): void
    {
        $conductor = (array) ($this->documento['conductor'] ?? []);
        if (empty($this->documento['vehiculo_placa']) || empty($conductor['numero']) || empty($conductor['licencia'])) {
            throw new InvalidArgumentException('Transporte privado: falta la placa, el documento o la licencia del conductor');
        }
        $envio->setVehiculo((new Vehicle())->setPlaca(strtoupper(str_replace('-', '', (string) $this->documento['vehiculo_placa']))));
        $envio->setChoferes([(new Driver())
            ->setTipo('Principal')
            ->setTipoDoc((string) ($conductor['tipo_documento'] ?? '1'))
            ->setNroDoc((string) $conductor['numero'])
            ->setLicencia(strtoupper((string) $conductor['licencia']))
            ->setNombres((string) ($conductor['nombres'] ?? ''))
            ->setApellidos((string) ($conductor['apellidos'] ?? ''))]);
    }

    private function detalles(): array
    {
        return array_map(
            static fn (array $item): DespatchDetail => (new DespatchDetail())
                ->setCantidad((float) $item['cantidad'])
                ->setUnidad((string) ($item['unidad'] ?? 'NIU'))
                ->setDescripcion((string) $item['descripcion'])
                ->setCodigo((string) ($item['codigo'] ?? '')),
            array_values(array_map(static fn ($item): array => (array) $item, (array) $this->documento['items'])),
        );
    }
}
