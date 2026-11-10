<?php

declare(strict_types=1);

namespace SunatGateway\Sunat;

final class ErrorDeRed
{
    private const PATRON = '/could not connect|connection (refused|reset|timed out)|timed? ?out|failed to connect|name or service not known|getaddrinfo|error fetching http headers|ssl|couldn\'t resolve|temporarily unavailable|503|502|504/i';

    public static function detectar(string $mensaje): bool
    {
        return (bool) preg_match(self::PATRON, $mensaje);
    }
}
