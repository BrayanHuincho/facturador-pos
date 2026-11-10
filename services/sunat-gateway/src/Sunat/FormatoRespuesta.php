<?php

declare(strict_types=1);

namespace SunatGateway\Sunat;

use Greenter\Model\Response\CdrResponse;
use Greenter\Model\Response\Error;

final class FormatoRespuesta
{
    public static function comprobante(bool $exito, ?string $xml, ?CdrResponse $cdr, ?string $cdrZip, ?Error $error): array
    {
        return [
            'exito' => $exito,
            'xml' => $xml ? base64_encode($xml) : null,
            'hash' => $xml ? self::hash($xml) : null,
            'cdr' => $cdrZip ? base64_encode($cdrZip) : null,
            'codigo' => $cdr?->getCode() ?? $error?->getCode(),
            'descripcion' => $cdr?->getDescription() ?? $error?->getMessage(),
            'notas' => $cdr?->getNotes() ?? [],
            'error' => self::error($error),
        ];
    }

    public static function error(?Error $error): ?array
    {
        if ($error === null) {
            return null;
        }
        $codigo = (string) $error->getCode();
        $mensaje = (string) $error->getMessage();

        return ['codigo' => $codigo, 'mensaje' => $mensaje, 'red' => $codigo === 'HTTP' || ErrorDeRed::detectar($mensaje)];
    }

    public static function hash(string $xml): ?string
    {
        return preg_match('/<ds:DigestValue[^>]*>([^<]+)<\/ds:DigestValue>/', $xml, $m) ? trim($m[1]) : null;
    }
}
