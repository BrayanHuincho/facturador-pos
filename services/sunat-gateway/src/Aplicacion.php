<?php

declare(strict_types=1);

namespace SunatGateway;

use InvalidArgumentException;
use SunatGateway\Configuracion\Entorno;
use SunatGateway\Controladores\BajaControlador;
use SunatGateway\Controladores\ConsultaCpeControlador;
use SunatGateway\Controladores\Controlador;
use SunatGateway\Controladores\FacturaControlador;
use SunatGateway\Controladores\FirmarControlador;
use SunatGateway\Controladores\GuiaControlador;
use SunatGateway\Controladores\GuiaEstadoControlador;
use SunatGateway\Controladores\NotaControlador;
use SunatGateway\Controladores\PdfControlador;
use SunatGateway\Controladores\ProbarControlador;
use SunatGateway\Controladores\ResumenControlador;
use SunatGateway\Controladores\SaludControlador;
use SunatGateway\Controladores\TicketControlador;
use SunatGateway\Http\Respuesta;
use SunatGateway\Sunat\ErrorDeRed;
use Throwable;

final class Aplicacion
{
    private const RUTAS_POST = [
        '/factura' => FacturaControlador::class,
        '/nota' => NotaControlador::class,
        '/resumen' => ResumenControlador::class,
        '/baja' => BajaControlador::class,
        '/ticket' => TicketControlador::class,
        '/consulta-cpe' => ConsultaCpeControlador::class,
        '/firmar' => FirmarControlador::class,
        '/probar' => ProbarControlador::class,
        '/guia' => GuiaControlador::class,
        '/guia-estado' => GuiaEstadoControlador::class,
        '/pdf' => PdfControlador::class,
    ];

    public function atender(): Respuesta
    {
        $metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';
        $ruta = rtrim(parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH) ?: '/', '/') ?: '/';

        if ($metodo === 'GET' && $ruta === '/salud') {
            return (new SaludControlador())([]);
        }
        if (!$this->tokenValido()) {
            return Respuesta::errorSimple(401, 'NO_AUTORIZADO', 'Token interno inválido');
        }
        if ($metodo !== 'POST') {
            return Respuesta::errorSimple(405, 'METODO', 'Solo POST');
        }
        $datos = json_decode(file_get_contents('php://input') ?: '', true);
        if (!is_array($datos)) {
            return Respuesta::errorSimple(400, 'JSON', 'Cuerpo JSON inválido');
        }
        $clase = self::RUTAS_POST[$ruta] ?? null;
        if ($clase === null) {
            return Respuesta::errorSimple(404, 'RUTA', "Ruta desconocida: {$ruta}");
        }

        return $this->ejecutar(new $clase(), $datos);
    }

    private function tokenValido(): bool
    {
        $esperado = Entorno::tokenInterno();
        $recibido = (string) ($_SERVER['HTTP_X_TOKEN_INTERNO'] ?? '');

        return $esperado !== '' && hash_equals($esperado, $recibido);
    }

    private function ejecutar(Controlador $controlador, array $datos): Respuesta
    {
        try {
            return $controlador($datos);
        } catch (InvalidArgumentException $e) {
            return Respuesta::json(422, ['exito' => false, 'error' => ['codigo' => 'DATOS', 'mensaje' => $e->getMessage(), 'red' => false]]);
        } catch (Throwable $e) {
            Registro::excepcion($e);

            return Respuesta::json(200, [
                'exito' => false,
                'xml' => null,
                'hash' => null,
                'cdr' => null,
                'codigo' => null,
                'descripcion' => null,
                'notas' => [],
                'error' => ['codigo' => 'EXCEPCION', 'mensaje' => $e->getMessage(), 'red' => ErrorDeRed::detectar($e->getMessage())],
            ]);
        }
    }
}
