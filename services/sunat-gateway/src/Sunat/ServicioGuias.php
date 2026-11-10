<?php

declare(strict_types=1);

namespace SunatGateway\Sunat;

use Greenter\Api;
use Greenter\Model\Response\Error;
use InvalidArgumentException;
use SunatGateway\Configuracion\Entorno;
use SunatGateway\Documentos\ConstructorGuia;
use ZipArchive;

final class ServicioGuias
{
    private const URL_BETA = 'https://gre-test.nubefact.com/v1';
    private const CODIGO_PENDIENTE = '98';
    private const REQUISITOS_PRODUCCION = [
        'api_client_id' => 'el Client ID de la API de SUNAT',
        'api_client_secret' => 'el Client Secret de la API de SUNAT',
        'usuario_sol' => 'el usuario SOL',
        'clave_sol' => 'la clave SOL',
        'certificado' => 'el certificado digital',
    ];

    public function __construct(private readonly SolicitudSunat $solicitud)
    {
    }

    public function enviar(): array
    {
        $api = $this->api();
        $resultado = $api->send((new ConstructorGuia($this->solicitud))->construir());
        $xml = $api->getLastXml();
        if (!$resultado || !$resultado->isSuccess()) {
            return $this->salida(false, $xml, null, $resultado?->getError());
        }

        return $this->salida(true, $xml, method_exists($resultado, 'getTicket') ? $resultado->getTicket() : null, null);
    }

    public function consultarEstado(): array
    {
        $ticket = (string) ($this->solicitud->documento['ticket'] ?? '');
        if ($ticket === '') {
            throw new InvalidArgumentException('Falta documento.ticket');
        }
        $estado = $this->api()->getStatus($ticket);
        $codigo = (string) ($estado->getCode() ?? '');
        if ($codigo === self::CODIGO_PENDIENTE) {
            return ['exito' => false, 'pendiente' => true, 'codigo' => self::CODIGO_PENDIENTE, 'descripcion' => 'SUNAT aún procesa la guía', 'cdr' => null, 'notas' => [], 'qr' => null, 'error' => null];
        }
        $cdr = $estado->getCdrResponse();
        $zip = $estado->getCdrZip();

        return [
            'exito' => $estado->isSuccess() && $cdr !== null && (int) $cdr->getCode() === 0,
            'pendiente' => false,
            'codigo' => $cdr?->getCode() ?? ($estado->getError()?->getCode() ?? $codigo),
            'descripcion' => $cdr?->getDescription() ?? $estado->getError()?->getMessage(),
            'notas' => $cdr?->getNotes() ?? [],
            'cdr' => $zip ? base64_encode($zip) : null,
            'qr' => $zip ? $this->qrDelCdr($zip) : null,
            'error' => $this->error($estado->getError()),
        ];
    }

    private function api(): Api
    {
        $api = $this->solicitud->esProduccion() ? $this->apiProduccion() : $this->apiBeta();
        $api->setBuilderOptions(['strict_variables' => true, 'optimizations' => 0, 'debug' => false, 'cache' => false]);

        return $api;
    }

    private function apiProduccion(): Api
    {
        $credenciales = $this->solicitud->credenciales;
        foreach (self::REQUISITOS_PRODUCCION as $campo => $nombre) {
            if (empty($credenciales[$campo])) {
                throw new InvalidArgumentException("Para emitir guías falta {$nombre} (Configuración › Empresa y SUNAT)");
            }
        }

        return (new Api())
            ->setApiCredentials((string) $credenciales['api_client_id'], (string) $credenciales['api_client_secret'])
            ->setClaveSOL($this->solicitud->ruc(), (string) $credenciales['usuario_sol'], (string) $credenciales['clave_sol'])
            ->setCertificate(Certificado::normalizar((string) $credenciales['certificado'], $credenciales['certificado_clave'] ?? null));
    }

    private function apiBeta(): Api
    {
        $credenciales = $this->solicitud->credenciales;
        $clientId = (string) (($credenciales['api_client_id'] ?? '') ?: Entorno::greBetaClientId());
        $clientSecret = (string) (($credenciales['api_client_secret'] ?? '') ?: Entorno::greBetaClientSecret());
        $usuario = (string) (($credenciales['usuario_sol'] ?? '') ?: Entorno::demoUsuario());
        $clave = (string) (($credenciales['clave_sol'] ?? '') ?: Entorno::greBetaClave());
        if ($clientId === '' || $clientSecret === '' || $usuario === '' || $clave === '') {
            throw new InvalidArgumentException('Faltan las credenciales demo de guías: envíalas en la petición o define GRE_BETA_CLIENT_ID, GRE_BETA_CLIENT_SECRET, SUNAT_DEMO_USUARIO y SUNAT_DEMO_CLAVE');
        }

        return (new Api(['auth' => self::URL_BETA, 'cpe' => self::URL_BETA]))
            ->setApiCredentials($clientId, $clientSecret)
            ->setClaveSOL($this->solicitud->ruc(), $usuario, $clave)
            ->setCertificate(Certificado::deSolicitudOPrueba($credenciales));
    }

    private function salida(bool $exito, ?string $xml, ?string $ticket, ?Error $error): array
    {
        return [
            'exito' => $exito,
            'ticket' => $ticket,
            'xml' => $xml ? base64_encode($xml) : null,
            'hash' => $xml ? FormatoRespuesta::hash($xml) : null,
            'codigo' => $error ? (string) $error->getCode() : null,
            'descripcion' => $error ? (string) $error->getMessage() : null,
            'error' => $this->error($error),
        ];
    }

    private function error(?Error $error): ?array
    {
        if ($error === null) {
            return null;
        }
        $mensaje = (string) $error->getMessage();

        return ['codigo' => (string) $error->getCode(), 'mensaje' => $mensaje, 'red' => ErrorDeRed::detectar($mensaje)];
    }

    private function qrDelCdr(string $zip): ?string
    {
        $xml = $this->xmlDelZip($zip);
        if (preg_match('#<cbc:DocumentDescription>\s*(https?://[^<\s]+)\s*</cbc:DocumentDescription>#', $xml, $m)) {
            return html_entity_decode($m[1]);
        }

        return preg_match('#https?://[^<\s"]*sunat\.gob\.pe[^<\s"]*#i', $xml, $m) ? html_entity_decode($m[0]) : null;
    }

    private function xmlDelZip(string $zip): string
    {
        $temporal = tempnam(sys_get_temp_dir(), 'cdr');
        file_put_contents($temporal, $zip);
        $xml = '';
        $archivo = new ZipArchive();
        if ($archivo->open($temporal) === true) {
            for ($i = 0; $i < $archivo->numFiles; $i++) {
                if (str_ends_with(strtolower((string) $archivo->getNameIndex($i)), '.xml')) {
                    $xml = (string) $archivo->getFromIndex($i);
                    break;
                }
            }
            $archivo->close();
        }
        @unlink($temporal);

        return $xml;
    }
}
