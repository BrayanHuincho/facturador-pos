<?php

declare(strict_types=1);

namespace SunatGateway\Sunat;

use Greenter\Model\DocumentInterface;
use Greenter\See;
use SunatGateway\Documentos\ConstructorFactura;
use SunatGateway\Documentos\ConstructorNota;
use Throwable;

final class ServicioComprobantes
{
    private const TICKET_INEXISTENTE = '202600000000001';

    public function __construct(private readonly SolicitudSunat $solicitud)
    {
    }

    public function enviarFactura(): array
    {
        return $this->enviar((new ConstructorFactura($this->solicitud))->construir());
    }

    public function enviarNota(): array
    {
        return $this->enviar((new ConstructorNota($this->solicitud))->construir());
    }

    public function firmar(): array
    {
        $tipo = (string) ($this->solicitud->documento['tipo_documento'] ?? '');
        $documento = in_array($tipo, ['07', '08'], true)
            ? (new ConstructorNota($this->solicitud))->construir()
            : (new ConstructorFactura($this->solicitud))->construir();
        $xml = FabricaSee::crear($this->solicitud)->getXmlSigned($documento);

        return FormatoRespuesta::comprobante(true, $xml, null, null, null);
    }

    public function probar(): array
    {
        $see = FabricaSee::crear($this->solicitud);
        $firma = $this->probarFirma($see);

        return [
            'exito' => (bool) $firma['ok'],
            'firma' => $firma,
            'sol' => $this->probarSol($see),
            'endpoint' => FabricaSee::endpoint($this->solicitud),
            'notas' => [],
            'error' => null,
        ];
    }

    private function enviar(DocumentInterface $documento): array
    {
        $see = FabricaSee::crear($this->solicitud);
        $resultado = $see->send($documento);
        $xml = $see->getFactory()->getLastXml();
        if ($resultado->isSuccess()) {
            return FormatoRespuesta::comprobante(true, $xml, $resultado->getCdrResponse(), $resultado->getCdrZip(), null);
        }

        return FormatoRespuesta::comprobante(false, $xml, null, null, $resultado->getError());
    }

    private function probarFirma(See $see): array
    {
        try {
            $muestra = $this->solicitud->conDocumento(self::documentoDeMuestra());
            $xml = $see->getXmlSigned((new ConstructorFactura($muestra))->construir());
            if (is_string($xml) && str_contains($xml, 'SignatureValue')) {
                return ['ok' => true, 'mensaje' => null];
            }

            return ['ok' => false, 'mensaje' => 'El XML no quedó firmado'];
        } catch (Throwable $e) {
            return ['ok' => false, 'mensaje' => 'No se pudo firmar con el certificado: ' . $e->getMessage()];
        }
    }

    private function probarEnvioBeta(See $see): array
    {
        try {
            $muestra = $this->solicitud->conDocumento(self::documentoDeMuestra());
            $resultado = $see->send((new ConstructorFactura($muestra))->construir());
            if ($resultado->isSuccess()) {
                return ['codigo' => '0', 'mensaje' => null];
            }
            $error = $resultado->getError();
            $codigo = (string) $error->getCode();

            return ['codigo' => ctype_digit($codigo) && (int) $codigo >= 2000 ? '0' : $codigo, 'mensaje' => (string) $error->getMessage()];
        } catch (Throwable $e) {
            return ['codigo' => ErrorDeRed::detectar($e->getMessage()) ? 'HTTP' : 'EXCEPCION', 'mensaje' => $e->getMessage()];
        }
    }

    private function probarSol(See $see): array
    {
        if (!$this->solicitud->esProduccion()) {
            return $this->probarEnvioBeta($see);
        }

        try {
            $resultado = $see->getStatus(self::TICKET_INEXISTENTE);
            $error = $resultado->getError();
            if ($error !== null) {
                return ['codigo' => (string) $error->getCode(), 'mensaje' => (string) $error->getMessage()];
            }

            return ['codigo' => (string) ($resultado->getCode() ?? '0'), 'mensaje' => $resultado->getCdrResponse()?->getDescription()];
        } catch (Throwable $e) {
            return ['codigo' => ErrorDeRed::detectar($e->getMessage()) ? 'HTTP' : 'EXCEPCION', 'mensaje' => $e->getMessage()];
        }
    }

    private static function documentoDeMuestra(): array
    {
        return [
            'tipo_documento' => '01',
            'serie' => 'F000',
            'correlativo' => '1',
            'moneda' => 'PEN',
            'forma_pago' => 'CONTADO',
            'cliente' => ['tipo_documento' => '6', 'numero_documento' => '20000000001', 'razon_social' => 'PRUEBA DE CONEXION'],
            'totales' => ['op_gravadas' => 1, 'igv' => 0.18, 'total_impuestos' => 0.18, 'valor_venta' => 1, 'sub_total' => 1.18, 'total' => 1.18],
            'items' => [[
                'codigo' => 'P',
                'descripcion' => 'PRUEBA',
                'unidad' => 'NIU',
                'cantidad' => 1,
                'valor_unitario' => 1,
                'precio_unitario' => 1.18,
                'tipo_afectacion_igv' => '10',
                'porcentaje_igv' => 18,
                'base_igv' => 1,
                'igv' => 0.18,
                'total_impuestos' => 0.18,
                'valor_venta' => 1,
            ]],
            'leyendas' => [['codigo' => '1000', 'valor' => 'SON UNO CON 18/100 SOLES']],
        ];
    }
}
