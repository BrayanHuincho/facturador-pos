<?php

declare(strict_types=1);

namespace SunatGateway\Controladores;

use InvalidArgumentException;
use SunatGateway\Http\Respuesta;
use SunatGateway\Pdf\GeneradorPdf;
use SunatGateway\Registro;
use Throwable;

final class PdfControlador implements Controlador
{
    public function __invoke(array $datos): Respuesta
    {
        try {
            return Respuesta::pdf((new GeneradorPdf($datos))->pdf());
        } catch (InvalidArgumentException $e) {
            return Respuesta::errorSimple(422, 'DATOS', $e->getMessage());
        } catch (Throwable $e) {
            Registro::excepcion($e, 'pdf');

            return Respuesta::errorSimple(500, 'PDF', $e->getMessage());
        }
    }
}
