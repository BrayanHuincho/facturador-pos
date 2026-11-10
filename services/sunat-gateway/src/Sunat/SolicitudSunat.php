<?php

declare(strict_types=1);

namespace SunatGateway\Sunat;

use InvalidArgumentException;

final readonly class SolicitudSunat
{
    public array $credenciales;
    public array $emisor;
    public array $documento;

    public function __construct(#[\SensitiveParameter] array $datos)
    {
        $this->credenciales = (array) ($datos['credenciales'] ?? []);
        $this->emisor = (array) ($datos['emisor'] ?? []);
        $this->documento = (array) ($datos['documento'] ?? []);
        if (empty($this->emisor['ruc']) || !preg_match('/^\d{11}$/', (string) $this->emisor['ruc'])) {
            throw new InvalidArgumentException('emisor.ruc debe tener 11 dígitos');
        }
    }

    public function ruc(): string
    {
        return (string) $this->emisor['ruc'];
    }

    public function esProduccion(): bool
    {
        return strtoupper((string) ($this->credenciales['entorno'] ?? 'PRUEBA')) === 'PRODUCCION';
    }

    public function conDocumento(array $documento): self
    {
        return new self(['credenciales' => $this->credenciales, 'emisor' => $this->emisor, 'documento' => $documento]);
    }
}
