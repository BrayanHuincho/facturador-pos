<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>{{ $doc['titulo'] }} {{ $doc['numero'] }}</title>
@php
    $f = $a5 ? 0.86 : 1;
    $pt = fn ($n) => round($n * $f, 2) . 'pt';
    $mm = fn ($n) => round($n * ($a5 ? 0.8 : 1), 2) . 'mm';
    $tinta = '#111111';
    $texto = '#2e2e2e';
    $suave = '#6b6b6b';
    $acento = '#2b2b2b';
    $sobre = '#ffffff';
    $oscuro = '#4a4a4a';
    $tinte = '#efefef';
    $linea = '#bdbdbd';
    $fina = '#dedede';
    $zebra = '#f7f7f7';
@endphp
<style>
    @font-face { font-family: 'Inter'; font-weight: normal; font-style: normal; src: url('{{ $fuentes }}/Inter-400.ttf') format('truetype'); }
    @font-face { font-family: 'Inter'; font-weight: bold; font-style: normal; src: url('{{ $fuentes }}/Inter-700.ttf') format('truetype'); }
    @font-face { font-family: 'InterSemi'; font-weight: normal; font-style: normal; src: url('{{ $fuentes }}/Inter-600.ttf') format('truetype'); }
    @font-face { font-family: 'InterSemi'; font-weight: bold; font-style: normal; src: url('{{ $fuentes }}/Inter-700.ttf') format('truetype'); }

    @page { margin: {{ $a5 ? '9mm 9mm 13mm 9mm' : '12mm 13mm 16mm 13mm' }}; }
    body, div, table, tr, td, th, img, span { margin: 0; padding: 0; }
    body { font-family: 'Inter', sans-serif; font-size: {{ $pt(8.4) }}; line-height: 1.34; color: {{ $texto }}; }
    table { border-collapse: collapse; width: 100%; }
    td, th { vertical-align: top; }
    .semi { font-family: 'InterSemi', sans-serif; }
    .b { font-weight: bold; }
    .der { text-align: right; }
    .cen { text-align: center; }
    .suave { color: {{ $suave }}; }
    .nowrap { white-space: nowrap; }

    .cab td { vertical-align: middle; }
    .logo { max-width: {{ $a5 ? '30mm' : '44mm' }}; max-height: {{ $a5 ? '16mm' : '21mm' }}; }
    .emisor { padding-left: {{ $logo ? $mm(5) : '0' }}; padding-right: {{ $mm(6) }}; }
    .razon { font-weight: bold; font-size: {{ $pt($logo ? ($a5 ? 12.5 : 14) : 15) }}; color: {{ $tinta }}; line-height: 1.2; }
    .comercial { font-family: 'InterSemi'; font-size: {{ $pt(8.6) }}; color: {{ $acento }}; margin-top: 1.5pt; }
    .lin { font-size: {{ $pt(7.8) }}; color: {{ $texto }}; margin-top: 1.6pt; }
    .lin-suave { font-size: {{ $pt(7.6) }}; color: {{ $suave }}; margin-top: 1.6pt; }
    .caja-doc { width: {{ $a5 ? '50mm' : '62mm' }}; border: 1.2pt solid {{ $acento }}; border-radius: 7pt; text-align: center; }
    .caja-doc .ruc { font-weight: bold; font-size: {{ $pt(11.5) }}; color: {{ $tinta }}; padding: {{ $mm(3) }} 0 {{ $mm(2.2) }}; letter-spacing: 0.4pt; }
    .caja-doc .tipo { background: {{ $acento }}; color: {{ $sobre }}; font-weight: bold; font-size: {{ $a5 ? '7.4pt' : '8.8pt' }}; padding: {{ $mm(2.1) }} {{ $mm(2) }}; letter-spacing: 0.6pt; text-transform: uppercase; }
    .caja-doc .num { font-weight: bold; font-size: {{ $pt(14) }}; color: {{ $tinta }}; padding: {{ $mm(2.5) }} 0 {{ $mm(2.9) }}; letter-spacing: 0.5pt; }

    .datos { margin-top: {{ $mm(5) }}; border: 0.7pt solid {{ $linea }}; border-radius: 6pt; }
    .datos-tabla > tbody > tr > td { padding: {{ $mm($a5 ? 2 : 2.4) }} {{ $mm(3.6) }}; }
    .pares td { padding: {{ $a5 ? "0.8pt" : "1.5pt" }} 0; font-size: {{ $pt(8.2) }}; vertical-align: top; }
    .pares td.e { font-family: 'InterSemi'; color: {{ $oscuro }}; white-space: nowrap; width: 1%; padding-right: {{ $mm(1.5) }}; text-transform: uppercase; font-size: {{ $pt(7.2) }}; letter-spacing: 0.4pt; padding-top: 2.3pt; }
    .pares td.s { width: 1%; padding-right: {{ $mm(2) }}; color: {{ $suave }}; }
    .pares td.v { color: {{ $tinta }}; }
    .pares td.v.fuerte { font-weight: bold; color: {{ $tinta }}; font-size: {{ $pt(8.8) }}; }

    .ref { margin-top: {{ $mm(2.6) }}; border: 0.7pt solid {{ $linea }}; border-radius: 6pt; padding: {{ $mm(2.2) }} {{ $mm(3.4) }}; }
    .rotulo { font-family: 'InterSemi'; font-size: {{ $pt(7.2) }}; color: {{ $oscuro }}; letter-spacing: 0.5pt; text-transform: uppercase; margin-bottom: 2pt; }

    .marco { margin-top: {{ $mm(4) }}; border: 0.7pt solid {{ $linea }}; }
    .items th { background: {{ $tinte }}; color: {{ $oscuro }}; font-family: 'InterSemi'; font-weight: normal; font-size: {{ $pt(7.2) }}; letter-spacing: 0.5pt; text-transform: uppercase; padding: {{ $mm(2.1) }} {{ $mm(1.6) }}; border-bottom: 0.7pt solid {{ $linea }}; border-left: 0.6pt solid {{ $fina }}; text-align: left; }
    .items th:first-child, .items td:first-child { border-left: none; }
    .items th.der { text-align: right; }
    .items th.cen { text-align: center; }
    .items td { padding: {{ $mm(1.8) }} {{ $mm(1.6) }}; border-left: 0.6pt solid {{ $fina }}; border-bottom: 0.5pt solid {{ $fina }}; font-size: {{ $pt(8.3) }}; color: {{ $texto }}; }
    .items tr { page-break-inside: avoid; }
    .items tr.relleno td { border-bottom: none; padding: 0; background: none; }
    .items .desc { color: {{ $tinta }}; }
    .items .cod { font-size: {{ $pt(7.4) }}; color: {{ $suave }}; }
    .items .afec { font-size: {{ $pt(6.6) }}; color: {{ $oscuro }}; font-family: 'InterSemi'; }
    .items .imp { font-family: 'InterSemi'; color: {{ $tinta }}; }

    .letras { margin-top: {{ $mm(2.6) }}; font-family: 'InterSemi'; font-size: {{ $pt(8.2) }}; color: {{ $tinta }}; }
    .letras span { color: {{ $oscuro }}; }
    .leyenda { font-family: 'InterSemi'; font-size: {{ $pt(7.3) }}; color: {{ $tinta }}; margin-top: 3pt; }
    .tot { margin-top: {{ $mm(1.8) }}; }
    .tot td { padding: 2.2pt {{ $mm(2.6) }}; font-size: {{ $pt(8.4) }}; border-bottom: 0.5pt solid {{ $fina }}; }
    .tot td.e { color: {{ $texto }}; }
    .tot td.m { width: 1%; color: {{ $suave }}; white-space: nowrap; padding-right: 0; }
    .tot td.v { text-align: right; color: {{ $tinta }}; font-family: 'InterSemi'; white-space: nowrap; width: 1%; padding-left: {{ $mm(3) }}; }
    .total { margin-top: {{ $mm(2) }}; background: {{ $acento }}; border-radius: 6pt; }
    .total td { padding: {{ $mm(2.6) }} {{ $mm(3) }}; color: {{ $sobre }}; vertical-align: middle; }
    .total .e { font-family: 'InterSemi'; font-size: {{ $pt(7.8) }}; letter-spacing: 0.7pt; text-transform: uppercase; }
    .total .v { font-weight: bold; font-size: {{ $pt(12.5) }}; text-align: right; white-space: nowrap; }
    .seccion { margin-top: {{ $mm(3.2) }}; }
    .tarjeta { margin-top: {{ $mm(3.2) }}; border: 0.7pt solid {{ $linea }}; border-radius: 6pt; padding: {{ $mm(2.4) }} {{ $mm(3) }}; }
    .mini { margin-top: 1pt; }
    .mini td, .mini th { font-size: {{ $pt(7.8) }}; padding: 1.6pt {{ $mm(1.6) }} 1.6pt 0; }
    .mini th { font-family: 'InterSemi'; font-weight: normal; color: {{ $suave }}; text-align: left; border-bottom: 0.6pt solid {{ $linea }}; }
    .mini th.der { text-align: right; }
    .mini td { border-bottom: 0.5pt solid {{ $fina }}; color: {{ $tinta }}; }

    .medio { border: 0.7pt solid {{ $linea }}; border-radius: 6pt; padding: {{ $mm(2.2) }} {{ $mm(2.6) }}; }
    .medio .ent { font-weight: bold; font-size: {{ $pt(8.2) }}; color: {{ $tinta }}; }
    .medio .sub { font-size: {{ $pt(6.8) }}; color: {{ $suave }}; margin-bottom: 1.5pt; }
    .medio td { font-size: {{ $pt(7.4) }}; padding: 0.6pt 0; }
    .medio img { width: {{ $mm(17) }}; height: {{ $mm(17) }}; }

    .sunat { margin-top: {{ $mm(5) }}; border-top: 0.7pt solid {{ $linea }}; padding-top: {{ $mm(3.4) }}; page-break-inside: avoid; }
    .sunat .qr { width: {{ $mm(26) }}; height: {{ $mm(26) }}; }
    .sunat .rep { font-weight: bold; font-size: {{ $pt(8.8) }}; color: {{ $tinta }}; }
    .sunat .txt { font-size: {{ $pt(7.6) }}; color: {{ $texto }}; margin-top: 2.2pt; }
    .sunat .hash { font-size: {{ $pt(7.3) }}; color: {{ $suave }}; margin-top: 3pt; }
    .sunat .legal { font-size: {{ $pt(7) }}; color: {{ $texto }}; margin-top: 4pt; padding-top: 3pt; border-top: 0.5pt dotted {{ $linea }}; }

</style>
</head>
<body>


<table class="cab">
    <tr>
        @if($logo)
            <td style="width: 1%;"><img class="logo" src="{{ $logo }}" alt=""></td>
        @endif
        <td class="emisor">
            <div class="razon">{{ $e['razon_social'] }}</div>
            @if($e['nombre_comercial'])<div class="comercial">{{ $e['nombre_comercial'] }}</div>@endif
            @if($e['direccion'])<div class="lin">{{ $e['direccion'] }}</div>@endif
            @if($e['sucursal'])<div class="lin">Establecimiento: {{ $e['sucursal'] }}</div>@endif
            @php $contacto = array_filter([$e['telefono'] ? 'Tel. ' . $e['telefono'] : null, $e['email'], $e['web']]); @endphp
            @if($contacto)<div class="lin-suave">{{ implode('  ·  ', $contacto) }}</div>@endif
        </td>
        <td style="width: {{ $a5 ? '50mm' : '62mm' }};">
            <div class="caja-doc">
                <div class="ruc">R.U.C. {{ $e['ruc'] }}</div>
                <div class="tipo">{{ $doc['titulo'] }}</div>
                <div class="num">{{ $doc['numero'] }}</div>
            </div>
        </td>
    </tr>
</table>

@php
    $cliente = array_filter([
        ($cli['etiqueta'] === 'Adquiriente' ? 'Señor(es)' : 'Cliente') => $cli['nombre'],
        ($cli['documento_tipo'] ?: 'Doc.') => $cli['documento_numero'],
        'Dirección' => $cli['direccion'],
    ]);
    $cliente += array_filter([
        'Moneda' => $doc['moneda'],
        'Forma de pago' => $doc['forma_pago'],
    ]);
    $condiciones = array_filter([
        ($a5 ? 'Emisión' : 'Fecha de emisión') => $doc['fecha_emision'] . ($doc['hora_emision'] ? '  ' . $doc['hora_emision'] : ''),
        ($a5 ? 'Vence' : 'Vencimiento') => $doc['fecha_vencimiento'],
        ...(($doc['simbolo'] ?? 'S/') !== 'S/' ? ['Tipo de cambio' => 'S/ ' . number_format($doc['tipo_cambio'] ?? 1, 3)] : []),
        ($a5 ? 'O. de compra' : 'Orden de compra') => $doc['orden_compra'] ?? null,
        'Referencia' => $doc['referencia'],
        'Vendedor' => $doc['vendedor'] ?? null,
    ]);
@endphp
<div class="datos"><table class="datos-tabla">
    <tr>
        <td style="width: {{ $a5 ? 54 : 57 }}%;">
            <table class="pares">
                @foreach($cliente as $etiqueta => $valor)
                    <tr><td class="e">{{ $etiqueta }}</td><td class="s">:</td><td class="v {{ $loop->first ? 'fuerte' : '' }}">{{ $valor }}</td></tr>
                @endforeach
            </table>
        </td>
        <td style="border-left: 0.6pt solid {{ $fina }};">
            <table class="pares">
                @foreach($condiciones as $etiqueta => $valor)
                    <tr><td class="e">{{ $etiqueta }}</td><td class="s">:</td><td class="v">{{ $valor }}</td></tr>
                @endforeach
            </table>
        </td>
    </tr>
</table></div>

@if($ref)
    <div class="ref">
        <table>
            <tr>
                <td style="width: 50%;">
                    <div class="rotulo">Documento que modifica</div>
                    <div class="semi" style="color: {{ $tinta }};">{{ $ref['tipo'] }} {{ $ref['numero'] }}@if($ref['fecha']) <span class="suave">· emitida el {{ $ref['fecha'] }}</span>@endif</div>
                </td>
                <td>
                    <div class="rotulo">Motivo</div>
                    <div class="semi" style="color: {{ $tinta }};">{{ $ref['motivo'] ?? '—' }}</div>
                </td>
            </tr>
        </table>
    </div>
@endif

@php
    $codigoEnColumna = $columnas['codigo'] && !$a5;
    $conPrecio = $columnas['precio'] ?? true;
    $columnasTabla = 5 + (!$a5 ? 1 : 0) + ($codigoEnColumna ? 1 : 0) + ($conPrecio ? 1 : 0) + ($columnas['descuento'] ? 1 : 0);
    $debajo = ($cuotas ? 16 + count($cuotas) * 5 : 0) + ($doc['observaciones'] ? 9 : 0) + ($medios ? 32 * ceil(count($medios) / 3) : 0)
        + ($detraccion ? 18 : 0) + ($ref ? 14 : 0) + count($leyendas) * 4 + max(0, count($totales) - 2) * 5 + ($texto_legal ? 10 : 0);
    $relleno = max(0, (($a5 ? 18 : 104) - count($items) * ($a5 ? 6 : 7) - $debajo * ($a5 ? 0.8 : 1)) * ($ajuste ?? 1));
@endphp
<div class="marco"><table class="items">
    <thead>
        <tr>
            @if(!$a5)<th class="cen" style="width: 6mm;">Ítem</th>@endif
            <th class="der" style="width: {{ $mm(11) }};">Cant.</th>
            <th class="cen" style="width: {{ $mm(10) }};">Und.</th>
            @if($codigoEnColumna)<th style="width: 17mm;">Código</th>@endif
            <th style="width: 100%;">Descripción</th>
            <th class="der" style="width: {{ $mm(16) }};">V. unit.</th>
            @if($conPrecio)<th class="der" style="width: {{ $mm(16) }};">P. unit.</th>@endif
            @if($columnas['descuento'])<th class="der" style="width: {{ $mm(13) }};">Dscto.</th>@endif
            <th class="der" style="width: {{ $mm(19) }};">Importe</th>
        </tr>
    </thead>
    <tbody>
        @foreach($items as $i)
            <tr>
                @if(!$a5)<td class="cen">{{ $i['n'] }}</td>@endif
                <td class="der semi" style="color: {{ $tinta }};">{{ $i['cantidad'] }}</td>
                <td class="cen">{{ $i['unidad'] }}</td>
                @if($codigoEnColumna)<td class="cod">{{ $i['codigo'] }}</td>@endif
                <td class="desc">
                    @if(!$codigoEnColumna && $i['codigo'])<div class="cod">{{ $i['codigo'] }}</div>@endif
                    {!! nl2br(e($i['descripcion'])) !!}
                    @if($i['afectacion'])<span class="afec">  · {{ $i['afectacion'] }}</span>@endif
                </td>
                <td class="der nowrap">{{ $i['valor_unitario'] }}</td>
                @if($conPrecio)<td class="der nowrap">{{ $i['precio_unitario'] }}</td>@endif
                @if($columnas['descuento'])<td class="der nowrap">{{ $i['descuento'] }}</td>@endif
                <td class="der nowrap imp">{{ $i['importe'] }}</td>
            </tr>
        @endforeach
        @if($relleno > 0)
            <tr class="relleno">
                @for($k = 0; $k < $columnasTabla; $k++)<td style="height: {{ $mm($relleno) }};"></td>@endfor
            </tr>
        @endif
    </tbody>
</table></div>

<table style="page-break-inside: avoid;">
    <tr>
        <td style="padding-right: {{ $mm(5) }};">
            <div class="letras"><span>SON:</span> {{ preg_replace('/^SON:\s*/i', '', $letras) }}</div>
            @foreach($leyendas as $l)
                <div class="leyenda">{{ $l }}</div>
            @endforeach

            @if($cuotas)
                <div class="tarjeta">
                    <div class="rotulo">Forma de pago: Crédito · {{ count($cuotas) }} {{ count($cuotas) === 1 ? 'cuota' : 'cuotas' }}</div>
                    <table class="mini">
                        <thead><tr><th>Cuota</th><th>Vencimiento</th><th class="der">Monto</th></tr></thead>
                        <tbody>
                            @foreach($cuotas as $q)
                                <tr><td>Cuota {{ $q['n'] }}</td><td>{{ $q['fecha'] }}</td><td class="der semi" style="color: {{ $tinta }};">{{ $doc['simbolo'] }} {{ $q['monto'] }}</td></tr>
                            @endforeach
                        </tbody>
                    </table>
                    <div class="semi" style="margin-top: 3pt; font-size: {{ $pt(8.2) }}; color: {{ $tinta }};">Monto neto pendiente de pago: {{ $doc['simbolo'] }} {{ $pendiente }}</div>
                </div>
            @endif

            @if($detraccion)
                <div class="seccion">
                    <div class="rotulo">Operación sujeta al Sistema de Pago de Obligaciones Tributarias</div>
                    <table class="pares">
                        @if($detraccion['bien'])<tr><td class="e">Bien o servicio</td><td class="s">:</td><td class="v">{{ $detraccion['bien'] }}</td></tr>@endif
                        <tr><td class="e">Porcentaje / monto</td><td class="s">:</td><td class="v">{{ $detraccion['porcentaje'] }} · {{ $detraccion['monto'] }}</td></tr>
                        @if($detraccion['cuenta'])<tr><td class="e">Cta. Banco de la Nación</td><td class="s">:</td><td class="v">{{ $detraccion['cuenta'] }}</td></tr>@endif
                    </table>
                </div>
            @endif

            @if($doc['observaciones'])
                <div class="seccion">
                    <table class="pares">
                        <tr><td class="e">Observaciones</td><td class="s">:</td><td class="v">{!! nl2br(e($doc['observaciones'])) !!}</td></tr>
                    </table>
                </div>
            @endif
        </td>
        <td style="width: {{ $mm(68) }};">
            <table class="tot">
                @foreach($totales as $t)
                    <tr><td class="e">{{ $t['etiqueta'] }}</td><td class="m">{{ $doc['simbolo'] }}</td><td class="v">{{ $t['valor'] }}</td></tr>
                @endforeach
            </table>
            <div class="total"><table><tr><td class="e">Importe total</td><td class="v">{{ $doc['simbolo'] }} {{ $total }}</td></tr></table></div>
        </td>
    </tr>
</table>

@if($medios)
    <div style="margin-top: {{ $mm(5) }}; page-break-inside: avoid;">
        <div class="rotulo">Cuentas para pagos</div>
        @php $porFila = $a5 ? 2 : 3; @endphp
        <table style="margin-top: 1pt;">
            @foreach(array_chunk($medios, $porFila) as $fila)
                <tr>
                    @foreach($fila as $k => $m)
                        <td style="width: {{ round(100 / $porFila, 2) }}%; padding: {{ $mm(1) }} {{ $k < $porFila - 1 ? $mm(1.6) : '0' }} {{ $mm(1) }} 0;">
                            <div class="medio">
                                <table><tr>
                                    <td>
                                        <div class="ent">{{ $m['entidad'] }}</div>
                                        <div class="sub">{{ $m['subtitulo'] }}</div>
                                        <table>
                                            @foreach($m['filas'] as $par)
                                                <tr><td class="suave" style="width: 32%;">{{ $par[0] }}</td><td class="semi" style="color: {{ $tinta }};">{{ $par[1] }}</td></tr>
                                            @endforeach
                                        </table>
                                        @if($m['nota'])<div class="sub" style="margin-top: 1.5pt;">{{ $m['nota'] }}</div>@endif
                                    </td>
                                    @if($m['qr'])<td style="width: 1%; padding-left: 2mm;"><img src="{{ $m['qr'] }}" alt=""></td>@endif
                                </tr></table>
                            </div>
                        </td>
                    @endforeach
                    @for($v = count($fila); $v < $porFila; $v++)<td></td>@endfor
                </tr>
            @endforeach
        </table>
    </div>
@endif

@unless($vista_previa && !$texto_legal)
<div class="sunat">
    <table>
        <tr>
            @if($qr)
                <td style="width: {{ $mm(30) }};"><img class="qr" src="{{ $qr }}" alt=""></td>
            @endif
            <td style="vertical-align: middle;">
                @unless($vista_previa)
                <div class="rep">{{ $representacion }}</div>
                <div class="txt">
                    Consulte su validez en SUNAT: <span class="semi">e-consulta.sunat.gob.pe</span>@if($consulta['web']) o en <span class="semi">{{ $consulta['web'] }}</span>@endif
                </div>
                @endunless
                @if($hash)<div class="hash">Código hash (resumen): <span class="semi" style="color: {{ $texto }};">{{ $hash }}</span></div>@endif
                @if($texto_legal)<div class="legal">{!! nl2br(e($texto_legal)) !!}</div>@endif
            </td>
        </tr>
    </table>
</div>
@endunless

</body>
</html>
