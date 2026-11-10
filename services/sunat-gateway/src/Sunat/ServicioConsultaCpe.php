<?php

declare(strict_types=1);

namespace SunatGateway\Sunat;

use Greenter\Ws\Services\ConsultCdrService;
use Greenter\Ws\Services\SoapClient;
use Greenter\Ws\Services\WsdlProvider;

final class ServicioConsultaCpe
{
    private const URL_CONSULTA = 'https://e-factura.sunat.gob.pe/ol-it-wsconscpegem/billConsultService';

    public function __construct(private readonly SolicitudSunat $solicitud)
    {
    }

    public function consultar(): array
    {
        $documento = $this->solicitud->documento;
        $ruc = $this->solicitud->ruc();
        $tipo = (string) $documento['tipo_documento'];
        $serie = (string) $documento['serie'];
        $correlativo = (int) $documento['correlativo'];

        $servicio = new ConsultCdrService();
        $servicio->setClient($this->clienteSoap());
        $resultado = !empty($documento['con_cdr'])
            ? $servicio->getStatusCdr($ruc, $tipo, $serie, $correlativo)
            : $servicio->getStatus($ruc, $tipo, $serie, $correlativo);
        $cdr = $resultado->getCdrResponse();
        $exito = $resultado->isSuccess();

        return [
            'exito' => $exito,
            'codigo' => $resultado->getCode(),
            'descripcion' => $resultado->getMessage(),
            'cdr' => $resultado->getCdrZip() ? base64_encode($resultado->getCdrZip()) : null,
            'cdr_codigo' => $cdr?->getCode(),
            'cdr_descripcion' => $cdr?->getDescription(),
            'notas' => $cdr?->getNotes() ?? [],
            'error' => $exito ? null : FormatoRespuesta::error($resultado->getError()),
        ];
    }

    private function clienteSoap(): SoapClient
    {
        $credenciales = $this->solicitud->credenciales;
        $cliente = new SoapClient(WsdlProvider::getConsultPath());
        $cliente->setService(self::URL_CONSULTA);
        $cliente->setCredentials($this->solicitud->ruc() . ($credenciales['usuario_sol'] ?? ''), (string) ($credenciales['clave_sol'] ?? ''));

        return $cliente;
    }
}
