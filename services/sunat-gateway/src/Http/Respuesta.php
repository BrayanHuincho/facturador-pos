<?php

declare(strict_types=1);

namespace SunatGateway\Http;

final readonly class Respuesta
{
    private function __construct(
        private int $estado,
        private string $cuerpo,
        private string $tipo,
    ) {
    }

    public static function json(int $estado, array $cuerpo): self
    {
        $json = json_encode($cuerpo, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRESERVE_ZERO_FRACTION);

        return new self($estado, (string) $json, 'application/json; charset=utf-8');
    }

    public static function errorSimple(int $estado, string $codigo, string $mensaje): self
    {
        return self::json($estado, ['exito' => false, 'error' => ['codigo' => $codigo, 'mensaje' => $mensaje]]);
    }

    public static function pdf(string $contenido): self
    {
        return new self(200, $contenido, 'application/pdf');
    }

    public function enviar(): void
    {
        http_response_code($this->estado);
        header('Content-Type: ' . $this->tipo);
        header('X-Content-Type-Options: nosniff');
        if ($this->tipo === 'application/pdf') {
            header('Content-Length: ' . strlen($this->cuerpo));
        }
        echo $this->cuerpo;
    }
}
