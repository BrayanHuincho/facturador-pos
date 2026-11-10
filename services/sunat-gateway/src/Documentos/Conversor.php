<?php

declare(strict_types=1);

namespace SunatGateway\Documentos;

use DateTime;
use DateTimeZone;
use InvalidArgumentException;

final class Conversor
{
    private const ZONA = 'America/Lima';

    public static function numero(mixed $valor): float
    {
        return round((float) $valor, 10);
    }

    public static function fecha(?string $fecha, ?string $hora = null): DateTime
    {
        $zona = new DateTimeZone(self::ZONA);
        if (!$fecha) {
            return new DateTime('now', $zona);
        }
        if (!preg_match('/^\d{4}-\d{2}-\d{2}/', $fecha)) {
            throw new InvalidArgumentException("Fecha no válida: {$fecha}");
        }
        $dia = substr($fecha, 0, 10);
        if ($hora && preg_match('/^\d{2}:\d{2}(:\d{2})?$/', $hora)) {
            return new DateTime("{$dia} {$hora}", $zona);
        }
        $hoy = (new DateTime('now', $zona))->format('Y-m-d');

        return $dia === $hoy ? new DateTime('now', $zona) : new DateTime("{$dia} 12:00:00", $zona);
    }

    public static function fechaGuia(string $dia, string $hora = ''): DateTime
    {
        $zona = new DateTimeZone(self::ZONA);
        if ($dia === 'now') {
            return new DateTime('now', $zona);
        }

        return new DateTime(trim($dia . ' ' . ($hora !== '' ? $hora : '12:00:00')), $zona);
    }

    public static function correlativoTresDigitos(array $documento): string
    {
        return str_pad((string) ($documento['correlativo'] ?? '1'), 3, '0', STR_PAD_LEFT);
    }
}
