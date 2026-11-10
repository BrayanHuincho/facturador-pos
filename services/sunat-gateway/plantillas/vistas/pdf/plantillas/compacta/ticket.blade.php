<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>{{ $doc['titulo'] }} {{ $doc['numero'] }}</title>
@php
    $angosto = $ancho_mm < 70;
    $pt = fn ($n) => round($angosto ? $n * 0.92 : $n, 2) . 'pt';
@endphp
<style>
    @include('pdf.plantillas.parciales.fuentes')
    @page { margin: {{ $angosto ? '1.5mm 2.5mm 0 2.5mm' : '2mm 3mm 0 3mm' }}; }
    body { font-family: 'DejaVu Sans Mono', monospace; font-size: {{ $pt(6.6) }}; line-height: 1.14; color: #000; }
    .logo { max-width: 22mm; max-height: 9mm; }
    .razon { font-weight: bold; font-size: {{ $pt(7.8) }}; }
    .lin { font-size: {{ $pt(6.1) }}; }
    .raya { border-top: 0.6pt dashed #000; margin: 0.8mm 0; height: 0; }
    .num { font-weight: bold; font-size: {{ $pt(8.2) }}; }
    td, th { font-size: {{ $pt(6.5) }}; }
    th { font-weight: bold; text-align: left; }
    th.der { text-align: right; }
    .gran td { font-weight: bold; font-size: {{ $pt(9) }}; }
    .qr { width: {{ $angosto ? '22mm' : '25mm' }}; height: {{ $angosto ? '22mm' : '25mm' }}; }
    .rep { font-weight: bold; font-size: {{ $pt(5.9) }}; }
    .txt, .hash, .legal { font-size: {{ $pt(5.7) }}; }
</style>
</head>
<body>
<div class="cen">
    @if($logo)<img class="logo" src="{{ $logo }}" alt=""><br>@endif
    <div class="razon">{{ $e['razon_social'] }}</div>
    <div class="lin">{{ implode(' · ', array_filter([$e['nombre_comercial'], $e['direccion'], $e['sucursal'], ...$contacto])) }}</div>
    <div class="lin">RUC {{ $e['ruc'] }} · {{ $doc['titulo'] }}</div>
    <div class="num">{{ $doc['numero'] }}</div>
</div>
<div class="raya"></div>
@foreach($filas_cliente as $k => $v)<div class="lin">{{ $k }}: {{ $v }}</div>@endforeach
@foreach($filas_documento as $k => $v)<div class="lin">{{ $k }}: {{ $v }}</div>@endforeach
<div class="raya"></div>
@if($angosto)
    @foreach($items as $i)
        <div>{{ $i['descripcion'] }}@if($i['codigo'] || $i['afectacion']) ({{ trim($i['codigo'] . ' ' . $i['afectacion']) }})@endif</div>
        <table><tr><td>{{ $i['cantidad'] }}{{ $i['unidad'] }}x{{ $i['precio_unitario'] }}</td><td class="der nowrap">{{ $i['importe'] }}</td></tr></table>
    @endforeach
@else
    <table>
        <thead><tr><th style="width: 13mm;">Cant</th><th>Descripción</th><th class="der" style="width: 13mm;">P.U.</th><th class="der" style="width: 15mm;">Imp.</th></tr></thead>
        <tbody>
        @foreach($items as $i)
            <tr><td class="nowrap">{{ $i['cantidad'] }}</td><td>{{ $i['descripcion'] }}@if($i['codigo'] || $i['afectacion']) ({{ trim($i['codigo'] . ' ' . $i['afectacion']) }})@endif</td><td class="der nowrap">{{ $i['precio_unitario'] }}</td><td class="der nowrap">{{ $i['importe'] }}</td></tr>
        @endforeach
        </tbody>
    </table>
@endif
<div class="raya"></div>
<table>
    @foreach($totales as $t)<tr><td>{{ $t['etiqueta'] }}</td><td class="der nowrap">{{ $doc['simbolo'] }} {{ $t['valor'] }}</td></tr>@endforeach
    <tr class="gran"><td>TOTAL</td><td class="der nowrap">{{ $doc['simbolo'] }} {{ $total }}</td></tr>
</table>
<div>SON: {{ $letras_limpias }}</div>
@foreach($leyendas as $l)<div>{{ $l }}</div>@endforeach
@include('pdf.plantillas.parciales.adicionales', ['tam' => $pt(6.2), 'separacion' => '1mm'])
<div class="raya"></div>
@if($angosto)
    @if($qr)<div class="cen"><img class="qr" src="{{ $qr }}" alt=""></div>@endif
    <div style="margin-top: 0.6mm;">@include('pdf.plantillas.parciales.textos-legales')</div>
@else
    <table><tr>
        @if($qr)<td style="width: 26mm;"><img class="qr" src="{{ $qr }}" alt=""></td>@endif
        <td style="padding-left: 1mm; vertical-align: middle;">@include('pdf.plantillas.parciales.textos-legales')</td>
    </tr></table>
@endif
<div style="height: 2mm;"></div>
</body>
</html>
