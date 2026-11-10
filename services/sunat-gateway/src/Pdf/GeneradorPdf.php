<?php

declare(strict_types=1);

namespace SunatGateway\Pdf;

use BaconQrCode\Renderer\Image\SvgImageBackEnd;
use BaconQrCode\Renderer\ImageRenderer;
use BaconQrCode\Renderer\RendererStyle\RendererStyle;
use BaconQrCode\Writer;
use Dompdf\Dompdf;
use Dompdf\Options;
use FilesystemIterator;
use Illuminate\Container\Container;
use Illuminate\Events\Dispatcher;
use Illuminate\Filesystem\Filesystem;
use Illuminate\View\Compilers\BladeCompiler;
use Illuminate\View\Engines\CompilerEngine;
use Illuminate\View\Engines\EngineResolver;
use Illuminate\View\Engines\PhpEngine;
use Illuminate\View\Factory;
use Illuminate\View\FileViewFinder;
use InvalidArgumentException;
use RecursiveDirectoryIterator;
use RecursiveIteratorIterator;

final class GeneradorPdf
{
    private const DISENO_PRINCIPAL = 'clasica';
    private const COLOR_POR_DISENO = [
        'clasica' => '#1e293b',
        'moderna' => '#0f766e',
        'minimalista' => '#111827',
        'ejecutiva' => '#1e3a5f',
        'compacta' => '#374151',
    ];
    private const TIPOS_DOCUMENTO = ['factura', 'boleta', 'nota-credito', 'nota-debito', 'nota-venta', 'guia'];
    private const PAPEL = [
        'A4' => null,
        'A5' => null,
        '80mm' => [80, 350],
        '50mm' => [58, 300],
    ];
    private const ALIAS_FORMATO = ['58mm' => '50mm'];
    private const MM_A_PUNTOS = 2.834645669;
    private const AJUSTES_RELLENO = [0.6, 0.3, 0];
    private const COLOR_MARCA_POR_DEFECTO = [0.97, 0.78, 0.78];
    private const COLORES_MARCA = [
        'PRUEBA' => [0.99, 0.88, 0.58],
        'VISTA PREVIA' => [0.82, 0.87, 0.94],
        'ANULADO' => [0.97, 0.78, 0.78],
        'RECHAZADO' => [0.97, 0.78, 0.78],
    ];
    private const ANGULO_MARCA = 35.0;
    private const TAMANO_MAXIMO_MARCA = 110.0;
    private const OCUPACION_MARCA = 0.88;
    private const SEPARACION_MARCAS_TICKET_MM = 297;

    private string $temporal;
    private bool $paginado = false;
    private ?string $sello = null;

    public function __construct(private readonly array $entrada)
    {
    }

    public function pdf(): string
    {
        $plantilla = (string) ($this->entrada['plantilla'] ?? self::DISENO_PRINCIPAL);
        $formato = (string) ($this->entrada['formato'] ?? 'A4');
        $formato = self::ALIAS_FORMATO[$formato] ?? $formato;
        $datos = (array) ($this->entrada['datos'] ?? []);
        if (!isset(self::COLOR_POR_DISENO[$plantilla]) && !in_array($plantilla, self::TIPOS_DOCUMENTO, true)) {
            throw new InvalidArgumentException("Plantilla desconocida: {$plantilla}");
        }
        if (!array_key_exists($formato, self::PAPEL)) {
            throw new InvalidArgumentException("Formato desconocido: {$formato}");
        }
        $diseno = isset(self::COLOR_POR_DISENO[$plantilla]) ? $plantilla : self::DISENO_PRINCIPAL;
        if ($formato === 'A5' && $diseno !== self::DISENO_PRINCIPAL) {
            throw new InvalidArgumentException('El formato A5 solo existe en la plantilla clasica');
        }

        $this->temporal = sys_get_temp_dir() . '/plantillas-' . bin2hex(random_bytes(8));
        mkdir($this->temporal, 0700, true);

        try {
            return $this->renderizar($plantilla === 'guia' || isset($datos['bloques']), $diseno, $formato, $datos);
        } finally {
            $this->borrar($this->temporal);
        }
    }

    private function renderizar(bool $esGuia, string $diseno, string $formato, array $datos): string
    {
        $this->paginado = in_array($formato, ['A4', 'A5'], true);
        $this->sello = !empty($datos['sello']) ? (string) $datos['sello'] : null;
        $variables = $esGuia ? $this->variablesGuia($datos) : $this->variablesComprobante($datos, $formato, $diseno);
        $vista = $this->vista($esGuia, $diseno);
        $html = $this->vistas()->make($vista, $variables)->render();
        if ($this->paginado && ($esGuia || $diseno === self::DISENO_PRINCIPAL)) {
            foreach (self::AJUSTES_RELLENO as $ajuste) {
                if ($this->paginas($html, $formato) <= 1) {
                    break;
                }
                $html = $this->vistas()->make($vista, ['ajuste' => $ajuste] + $variables)->render();
            }
        }

        return $this->dompdf($html, $formato);
    }

    private function vista(bool $esGuia, string $diseno): string
    {
        $hoja = $this->paginado ? 'hoja' : 'ticket';
        if ($esGuia) {
            return "pdf.guia.{$hoja}";
        }

        return $diseno === self::DISENO_PRINCIPAL ? "pdf.comprobante.{$hoja}" : "pdf.plantillas.{$diseno}.{$hoja}";
    }

    private function variablesComprobante(array $d, string $formato, string $diseno): array
    {
        $ticket = !in_array($formato, ['A4', 'A5'], true);
        $lista = static fn (string $clave): array => array_values(array_map(static fn ($x): array => (array) $x, (array) ($d[$clave] ?? [])));
        $emisor = (array) ($d['emisor'] ?? []) + array_fill_keys(['razon_social', 'nombre_comercial', 'direccion', 'sucursal', 'telefono', 'email', 'web', 'ruc'], null);
        $documento = (array) ($d['documento'] ?? []) + array_fill_keys(['titulo', 'numero', 'moneda', 'forma_pago', 'fecha_emision', 'hora_emision', 'fecha_vencimiento', 'orden_compra', 'referencia', 'vendedor', 'observaciones'], null) + ['simbolo' => 'S/', 'tipo_cambio' => 1];
        $cliente = (array) ($d['cliente'] ?? []) + array_fill_keys(['etiqueta', 'nombre', 'documento_tipo', 'documento_numero', 'direccion'], null);
        $referencia = isset($d['referencia']) && is_array($d['referencia']) ? $d['referencia'] : null;
        $letras = (string) ($d['letras'] ?? '');

        return [
            'e' => $emisor,
            'doc' => $documento,
            'cli' => $cliente,
            'ref' => $referencia,
            'columnas' => (array) ($d['columnas'] ?? []) + ['codigo' => false, 'descuento' => false],
            'items' => $lista('items'),
            'totales' => $lista('totales'),
            'total' => (string) ($d['total'] ?? '0.00'),
            'letras' => $letras,
            'letras_limpias' => (string) preg_replace('/^SON:\s*/i', '', $letras),
            'cuotas' => $lista('cuotas'),
            'pendiente' => $d['credito_pendiente'] ?? null,
            'detraccion' => isset($d['detraccion']) && is_array($d['detraccion']) ? $d['detraccion'] : null,
            'leyendas' => array_values(array_filter(array_map('strval', (array) ($d['leyendas'] ?? [])))),
            'medios' => $lista('medios'),
            'hash' => $d['hash'] ?? null,
            'representacion' => (string) ($d['representacion'] ?? ''),
            'consulta' => (array) ($d['consulta'] ?? []) + ['web' => null],
            'texto_legal' => $d['texto_legal'] ?? null,
            'sello' => $d['sello'] ?? null,
            'vista_previa' => !empty($d['vista_previa']),
            'qr' => $this->qrSvg(),
            'logo' => $this->logoDataUri(),
            'c' => $this->paleta((string) ($d['color'] ?? self::COLOR_POR_DISENO[$diseno])),
            'a5' => $formato === 'A5',
            'ancho_mm' => $ticket ? self::PAPEL[$formato][0] : null,
            'fuentes' => $this->rutaFuentes(),
            'filas_cliente' => $this->filasCliente($cliente),
            'filas_documento' => $this->filasDocumento($documento, $referencia),
            'contacto' => array_values(array_filter([$emisor['telefono'] ? 'Tel. ' . $emisor['telefono'] : null, $emisor['email'], $emisor['web']])),
        ];
    }

    private function filasCliente(array $cliente): array
    {
        return array_filter([
            ($cliente['etiqueta'] ?: 'Cliente') => $cliente['nombre'],
            ($cliente['documento_tipo'] ?: 'Doc.') => $cliente['documento_numero'],
            'Dirección' => $cliente['direccion'],
        ]);
    }

    private function filasDocumento(array $documento, ?array $referencia): array
    {
        $extranjera = ($documento['simbolo'] ?? 'S/') !== 'S/';

        return array_filter([
            'Emisión' => trim($documento['fecha_emision'] . ' ' . $documento['hora_emision']),
            'Vencimiento' => $documento['fecha_vencimiento'],
            'Moneda' => $documento['moneda'],
            'Tipo de cambio' => $extranjera ? 'S/ ' . number_format((float) $documento['tipo_cambio'], 3) : null,
            'Forma de pago' => $documento['forma_pago'],
            'Orden de compra' => $documento['orden_compra'],
            'Referencia' => $documento['referencia'],
            'Vendedor' => $documento['vendedor'],
            'Modifica a' => $referencia ? trim(($referencia['tipo'] ?? '') . ' ' . ($referencia['numero'] ?? '') . (empty($referencia['fecha']) ? '' : ' del ' . $referencia['fecha'])) : null,
            'Motivo' => $referencia['motivo'] ?? null,
        ]);
    }

    private function variablesGuia(array $d): array
    {
        $bloques = array_values(array_map(static fn (array $b): array => [
            'titulo' => (string) ($b['titulo'] ?? ''),
            'pares' => array_values(array_map(static fn ($p): array => [(string) ($p[0] ?? ''), (string) ($p[1] ?? '')], (array) ($b['pares'] ?? []))),
        ], array_map(static fn ($x): array => (array) $x, (array) ($d['bloques'] ?? []))));

        return [
            'e' => (array) ($d['emisor'] ?? []),
            'doc' => (array) ($d['documento'] ?? []),
            'bloques' => $bloques,
            'items' => array_values(array_map(static fn ($x): array => (array) $x, (array) ($d['items'] ?? []))),
            'observaciones' => $d['observaciones'] ?? null,
            'hash' => $d['hash'] ?? null,
            'representacion' => (string) ($d['representacion'] ?? ''),
            'sello' => $d['sello'] ?? null,
            'qr' => $this->qrSvg(),
            'logo' => $this->logoDataUri(),
            'fuentes' => $this->rutaFuentes(),
        ];
    }

    private function rutaFuentes(): string
    {
        return dirname(__DIR__, 2) . '/plantillas/publico/fuentes';
    }

    private function qrSvg(): ?string
    {
        $texto = (string) ($this->entrada['qr_texto'] ?? '');
        if ($texto === '') {
            return null;
        }
        $svg = (new Writer(new ImageRenderer(new RendererStyle(400, 0), new SvgImageBackEnd())))->writeString($texto);

        return 'data:image/svg+xml;base64,' . base64_encode($svg);
    }

    private function logoDataUri(): ?string
    {
        $bytes = base64_decode((string) ($this->entrada['logo'] ?? ''), true);
        if ($bytes === false || $bytes === '') {
            return null;
        }
        if (str_starts_with($bytes, "\x89PNG")) {
            return 'data:image/png;base64,' . base64_encode($bytes);
        }
        if (str_starts_with($bytes, "\xFF\xD8\xFF")) {
            return 'data:image/jpeg;base64,' . base64_encode($bytes);
        }

        return null;
    }

    private function paleta(string $hex): array
    {
        if (!preg_match('/^#?([0-9a-f]{6})$/i', $hex, $m)) {
            $m = [1 => '1e293b'];
        }
        [$r, $g, $b] = array_map('hexdec', str_split($m[1], 2));
        $luz = static fn (array $c): float => (0.2126 * $c[0] + 0.7152 * $c[1] + 0.0722 * $c[2]) / 255;
        $mezcla = static fn (array $c, array $con, float $t): array => array_map(static fn ($x, $y): int => (int) round($x + ($y - $x) * $t), $c, $con);
        $acento = [$r, $g, $b];
        if ($luz($acento) > 0.62) {
            $acento = $mezcla($acento, [0, 0, 0], 0.35);
        }
        $css = static fn (array $c): string => sprintf('#%02x%02x%02x', ...$c);

        return [
            'acento' => $css($acento),
            'sobre' => $luz($acento) > 0.55 ? '#0f172a' : '#ffffff',
            'oscuro' => $css($mezcla($acento, [15, 23, 42], 0.45)),
            'tinte' => $css($mezcla($acento, [255, 255, 255], 0.92)),
            'tinta' => '#0f172a',
            'texto' => '#334155',
            'suave' => '#64748b',
            'linea' => '#dde3ea',
        ];
    }

    private function vistas(): Factory
    {
        $archivos = new Filesystem();
        $cache = sys_get_temp_dir() . '/plantillas-blade';
        if (!is_dir($cache)) {
            @mkdir($cache, 0700, true);
        }
        $blade = new BladeCompiler($archivos, $cache);
        $motores = new EngineResolver();
        $motores->register('blade', static fn () => new CompilerEngine($blade, $archivos));
        $motores->register('php', static fn () => new PhpEngine($archivos));
        $buscador = new FileViewFinder($archivos, [dirname(__DIR__, 2) . '/plantillas/vistas']);
        $fabrica = new Factory($motores, $buscador, new Dispatcher(new Container()));
        $fabrica->setContainer(new Container());

        return $fabrica;
    }

    private function nuevoDompdf(string $html): Dompdf
    {
        $opciones = new Options();
        $opciones->set('defaultFont', 'Arial');
        $opciones->set('isRemoteEnabled', false);
        $opciones->set('isHtml5ParserEnabled', true);
        $opciones->set('isFontSubsettingEnabled', true);
        $opciones->set('tempDir', $this->temporal);
        $fuentes = sys_get_temp_dir() . '/dompdf-fuentes';
        if (!is_dir($fuentes)) {
            @mkdir($fuentes, 0700, true);
        }
        $opciones->set('fontDir', $fuentes);
        $opciones->set('fontCache', $fuentes);
        $opciones->set('chroot', [dirname(__DIR__, 2) . '/plantillas', $this->temporal]);
        $pdf = new Dompdf($opciones);
        $pdf->loadHtml($html, 'UTF-8');

        return $pdf;
    }

    private function paginas(string $html, string $formato): int
    {
        $pdf = $this->nuevoDompdf($html);
        $pdf->setPaper($formato, 'portrait');
        $pdf->render();

        return (int) $pdf->getCanvas()->get_page_count();
    }

    private function dompdf(string $html, string $formato): string
    {
        $papel = self::PAPEL[$formato];

        return $papel === null ? $this->hoja($html, $formato) : $this->ticket($html, $papel);
    }

    private function hoja(string $html, string $formato): string
    {
        $pdf = $this->nuevoDompdf($html);
        $this->agregarMarcaDeAgua($pdf);
        $pdf->setPaper($formato, 'portrait');
        $pdf->render();
        if (!$this->paginado) {
            return (string) $pdf->output();
        }
        $lienzo = $pdf->getCanvas();
        $metricas = $pdf->getFontMetrics();
        $fuente = $metricas->getFont('Inter') ?? $metricas->getFont('helvetica');
        $tam = $formato === 'A5' ? 5.7 : 6.6;
        $margen = ($formato === 'A5' ? 9 : 13) * self::MM_A_PUNTOS;
        $ancho = $metricas->getTextWidth('Página 8 de 8', $fuente, $tam);
        if ($lienzo->get_page_count() > 1) {
            $lienzo->page_text($lienzo->get_width() - $margen - $ancho, $lienzo->get_height() - $margen * ($formato === 'A5' ? 0.95 : 0.78), 'Página {PAGE_NUM} de {PAGE_COUNT}', $fuente, $tam, [0.45, 0.45, 0.45]);
        }

        return (string) $pdf->output();
    }

    private function ticket(string $html, array $papel): string
    {
        $mm = self::MM_A_PUNTOS;
        $ancho = $papel[0] * $mm;
        $medida = $this->nuevoDompdf($html);
        $medida->setPaper([0, 0, $ancho, 3000 * $mm], 'portrait');
        $fondo = 0.0;
        $medida->setCallbacks([[
            'event' => 'end_frame',
            'f' => static function ($marco) use (&$fondo): void {
                $nodo = $marco->get_node();
                $elemento = $nodo instanceof \DOMElement ? $nodo : $nodo->parentNode;
                if (in_array(strtolower($nodo->nodeName), ['html', 'body'], true)
                    || ($elemento instanceof \DOMElement && str_contains((string) $elemento->getAttribute('class'), 'watermark'))) {
                    return;
                }
                $caja = $marco->get_border_box();
                $fondo = max($fondo, (float) $caja['y'] + (float) $caja['h']);
            },
        ]]);
        $medida->render();
        $alto = $fondo > 0 ? max($fondo + 1 * $mm, 40 * $mm) : $papel[1] * $mm;
        $pdf = $this->nuevoDompdf($html);
        $this->agregarMarcaDeAgua($pdf);
        $pdf->setPaper([0, 0, $ancho, $alto], 'portrait');
        $pdf->render();

        return (string) $pdf->output();
    }

    private function agregarMarcaDeAgua(Dompdf $pdf): void
    {
        if ($this->sello === null) {
            return;
        }
        $sello = $this->sello;
        $color = self::COLORES_MARCA[$sello] ?? self::COLOR_MARCA_POR_DEFECTO;
        $pdf->setCallbacks([[
            'event' => 'begin_page_render',
            'f' => static function ($marco, $lienzo, $metricas) use ($sello, $color): void {
                self::dibujarMarcaDeAgua($lienzo, $metricas, $sello, $color);
            },
        ]]);
    }

    private static function dibujarMarcaDeAgua($lienzo, $metricas, string $sello, array $color): void
    {
        $fuente = $metricas->getFont('Inter', 'bold') ?? $metricas->getFont('helvetica', 'bold');
        $ancho = (float) $lienzo->get_width();
        $alto = (float) $lienzo->get_height();
        $radianes = deg2rad(self::ANGULO_MARCA);
        $coseno = cos($radianes);
        $seno = sin($radianes);
        $referencia = 100.0;
        $anchoPorPunto = $metricas->getTextWidth($sello, $fuente, $referencia) / $referencia;
        $tamano = min(
            self::TAMANO_MAXIMO_MARCA,
            $ancho * self::OCUPACION_MARCA / ($anchoPorPunto * $coseno + 0.75 * $seno),
            $alto * self::OCUPACION_MARCA / ($anchoPorPunto * $seno + 0.75 * $coseno),
        );
        $anchoTexto = $anchoPorPunto * $tamano;
        $altoFuente = (float) $metricas->getFontHeight($fuente, $tamano);
        $separacion = self::SEPARACION_MARCAS_TICKET_MM * self::MM_A_PUNTOS;
        $copias = max(1, (int) floor($alto / $separacion));
        for ($i = 0; $i < $copias; $i++) {
            $centroY = $alto * ($i + 0.5) / $copias;
            $x = $ancho / 2 - ($anchoTexto / 2) * $coseno + (0.36 * $tamano) * $seno;
            $y = $centroY + ($anchoTexto / 2) * $seno + (0.36 * $tamano) * $coseno;
            $lienzo->text($x, $y - $altoFuente, $sello, $fuente, $tamano, $color, 0.0, 0.0, -self::ANGULO_MARCA);
        }
    }

    private function borrar(string $carpeta): void
    {
        if (!is_dir($carpeta)) {
            return;
        }
        $elementos = new RecursiveIteratorIterator(
            new RecursiveDirectoryIterator($carpeta, FilesystemIterator::SKIP_DOTS),
            RecursiveIteratorIterator::CHILD_FIRST,
        );
        foreach ($elementos as $e) {
            $e->isDir() ? @rmdir($e->getPathname()) : @unlink($e->getPathname());
        }
        @rmdir($carpeta);
    }
}
