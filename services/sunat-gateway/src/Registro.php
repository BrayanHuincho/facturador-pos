<?php

declare(strict_types=1);

namespace SunatGateway;

use Throwable;

final class Registro
{
    public static function excepcion(Throwable $e, string $contexto = 'peticion'): void
    {
        error_log(sprintf('[sunat-gateway] %s %s @ %s:%d', $contexto, $e::class, basename($e->getFile()), $e->getLine()));
    }
}
