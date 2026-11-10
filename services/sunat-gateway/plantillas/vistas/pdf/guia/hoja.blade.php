<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>{{ $doc['titulo'] }} {{ $doc['numero'] }}</title>
@php
    $tinta = '#111111'; $texto = '#2e2e2e'; $suave = '#6b6b6b'; $acento = '#2b2b2b'; $sobre = '#ffffff';
    $oscuro = '#4a4a4a'; $tinte = '#efefef'; $linea = '#bdbdbd'; $fina = '#dedede';
    $relleno = max(0, (78 - count($items) * 7 - count($bloques) * 4 - ($observaciones ? 9 : 0)) * ($ajuste ?? 1));
@endphp
<style>
    @font-face { font-family: 'Inter'; font-weight: normal; font-style: normal; src: url('{{ $fuentes }}/Inter-400.ttf') format('truetype'); }
    @font-face { font-family: 'Inter'; font-weight: bold; font-style: normal; src: url('{{ $fuentes }}/Inter-700.ttf') format('truetype'); }
    @font-face { font-family: 'InterSemi'; font-weight: normal; font-style: normal; src: url('{{ $fuentes }}/Inter-600.ttf') format('truetype'); }
    @page { margin: 12mm 13mm 16mm 13mm; }
    body, div, table, tr, td, th, img, span { margin: 0; padding: 0; }
    body { font-family: 'Inter', sans-serif; font-size: 8.4pt; line-height: 1.34; color: {{ $texto }}; }
    table { border-collapse: collapse; width: 100%; }
    td, th { vertical-align: top; }
    .semi { font-family: 'InterSemi', sans-serif; }
    .der { text-align: right; }
    .cen { text-align: center; }
    .cab td { vertical-align: middle; }
    .logo { max-width: 44mm; max-height: 21mm; }
    .emisor { padding-left: {{ $logo ? '5mm' : '0' }}; padding-right: 6mm; }
    .razon { font-weight: bold; font-size: {{ $logo ? '14pt' : '15pt' }}; color: {{ $tinta }}; line-height: 1.2; }
    .comercial { font-family: 'InterSemi'; font-size: 8.6pt; color: {{ $acento }}; margin-top: 1.5pt; }
    .lin { font-size: 7.8pt; margin-top: 1.6pt; }
    .lin-suave { font-size: 7.6pt; color: {{ $suave }}; margin-top: 1.6pt; }
    .caja-doc { width: 62mm; border: 1.2pt solid {{ $acento }}; border-radius: 7pt; text-align: center; }
    .caja-doc .ruc { font-weight: bold; font-size: 11.5pt; color: {{ $tinta }}; padding: 3mm 0 2.2mm; letter-spacing: 0.4pt; }
    .caja-doc .tipo { background: {{ $acento }}; color: {{ $sobre }}; font-weight: bold; font-size: 8.2pt; padding: 2.1mm 2mm; letter-spacing: 0.5pt; text-transform: uppercase; }
    .caja-doc .num { font-weight: bold; font-size: 14pt; color: {{ $tinta }}; padding: 2.5mm 0 2.9mm; letter-spacing: 0.5pt; }
    .bloques { margin-top: 4mm; }
    .bloque { border: 0.7pt solid {{ $linea }}; border-radius: 6pt; padding: 2.2mm 3.2mm; }
    .rotulo { font-family: 'InterSemi'; font-size: 7.2pt; color: {{ $oscuro }}; letter-spacing: 0.5pt; text-transform: uppercase; margin-bottom: 1.5pt; border-bottom: 0.5pt solid {{ $fina }}; padding-bottom: 1.2pt; }
    .pares td { padding: 1.2pt 0; font-size: 8pt; }
    .pares td.e { font-family: 'InterSemi'; color: {{ $oscuro }}; white-space: nowrap; width: 1%; padding-right: 1.5mm; text-transform: uppercase; font-size: 6.9pt; letter-spacing: 0.3pt; padding-top: 2pt; }
    .pares td.s { width: 1%; padding-right: 2mm; color: {{ $suave }}; }
    .pares td.v { color: {{ $tinta }}; }
    .marco { margin-top: 4mm; border: 0.7pt solid {{ $linea }}; }
    .items th { background: {{ $tinte }}; color: {{ $oscuro }}; font-family: 'InterSemi'; font-weight: normal; font-size: 7.2pt; letter-spacing: 0.5pt; text-transform: uppercase; padding: 2.1mm 1.6mm; border-bottom: 0.7pt solid {{ $linea }}; border-left: 0.6pt solid {{ $fina }}; text-align: left; }
    .items th:first-child, .items td:first-child { border-left: none; }
    .items th.der { text-align: right; } .items th.cen { text-align: center; }
    .items td { padding: 1.8mm 1.6mm; border-left: 0.6pt solid {{ $fina }}; border-bottom: 0.5pt solid {{ $fina }}; font-size: 8.3pt; }
    .items tr { page-break-inside: avoid; }
    .items tr.relleno td { border-bottom: none; padding: 0; }
    .items .cod { font-size: 7.4pt; color: {{ $suave }}; }
    .sunat { margin-top: 5mm; border-top: 0.7pt solid {{ $linea }}; padding-top: 3.4mm; page-break-inside: avoid; }
    .sunat .qr { width: 26mm; height: 26mm; }
    .sunat .rep { font-weight: bold; font-size: 8.8pt; color: {{ $tinta }}; }
    .sunat .txt { font-size: 7.6pt; margin-top: 2.2pt; }
    .sunat .hash { font-size: 7.3pt; color: {{ $suave }}; margin-top: 3pt; }
</style>
</head>
<body>

<table class="cab">
    <tr>
        @if($logo)<td style="width: 1%;"><img class="logo" src="{{ $logo }}" alt=""></td>@endif
        <td class="emisor">
            <div class="razon">{{ $e['razon_social'] }}</div>
            @if(!empty($e['nombre_comercial']))<div class="comercial">{{ $e['nombre_comercial'] }}</div>@endif
            @if(!empty($e['direccion']))<div class="lin">{{ $e['direccion'] }}</div>@endif
            @php $contacto = array_filter([!empty($e['telefono']) ? 'Tel. ' . $e['telefono'] : null, $e['email'] ?? null, $e['web'] ?? null]); @endphp
            @if($contacto)<div class="lin-suave">{{ implode('  ·  ', $contacto) }}</div>@endif
        </td>
        <td style="width: 62mm;">
            <div class="caja-doc">
                <div class="ruc">R.U.C. {{ $e['ruc'] }}</div>
                <div class="tipo">{{ $doc['titulo'] }}</div>
                <div class="num">{{ $doc['numero'] }}</div>
            </div>
        </td>
    </tr>
</table>

<table class="bloques">
    @foreach(array_chunk($bloques, 2) as $fila)
        <tr>
            @foreach($fila as $k => $b)
                <td style="width: 50%; padding: 0 {{ $k === 0 ? '1.4mm' : '0' }} 2.6mm {{ $k === 1 ? '1.4mm' : '0' }};">
                    <div class="bloque">
                        <div class="rotulo">{{ $b['titulo'] }}</div>
                        <table class="pares">
                            @foreach($b['pares'] as $par)
                                <tr><td class="e">{{ $par[0] }}</td><td class="s">:</td><td class="v">{{ $par[1] }}</td></tr>
                            @endforeach
                        </table>
                    </div>
                </td>
            @endforeach
            @if(count($fila) === 1)<td></td>@endif
        </tr>
    @endforeach
</table>

<div class="marco"><table class="items">
    <thead>
        <tr>
            <th class="cen" style="width: 8mm;">Ítem</th>
            <th style="width: 22mm;">Código</th>
            <th style="width: 100%;">Descripción</th>
            <th class="cen" style="width: 14mm;">Und.</th>
            <th class="der" style="width: 20mm;">Cantidad</th>
        </tr>
    </thead>
    <tbody>
        @foreach($items as $i)
            <tr>
                <td class="cen">{{ $i['n'] }}</td>
                <td class="cod">{{ $i['codigo'] }}</td>
                <td style="color: {{ $tinta }};">{!! nl2br(e($i['descripcion'])) !!}</td>
                <td class="cen">{{ $i['unidad'] }}</td>
                <td class="der semi" style="color: {{ $tinta }};">{{ $i['cantidad'] }}</td>
            </tr>
        @endforeach
        @if($relleno > 0)
            <tr class="relleno">@for($k = 0; $k < 5; $k++)<td style="height: {{ round($relleno, 2) }}mm;"></td>@endfor</tr>
        @endif
    </tbody>
</table></div>

@if($observaciones)
    <table class="pares" style="margin-top: 3mm;">
        <tr><td class="e">Observaciones</td><td class="s">:</td><td class="v">{!! nl2br(e($observaciones)) !!}</td></tr>
    </table>
@endif

<div class="sunat">
    <table>
        <tr>
            @if($qr)<td style="width: 30mm;"><img class="qr" src="{{ $qr }}" alt=""></td>@endif
            <td style="vertical-align: middle;">
                <div class="rep">{{ $representacion }}</div>
                <div class="txt">Consulte su validez escaneando el código QR o en <span class="semi">e-consulta.sunat.gob.pe</span></div>
                @if($hash)<div class="hash">Código hash (resumen): <span class="semi" style="color: {{ $texto }};">{{ $hash }}</span></div>@endif
            </td>
        </tr>
    </table>
</div>

</body>
</html>
