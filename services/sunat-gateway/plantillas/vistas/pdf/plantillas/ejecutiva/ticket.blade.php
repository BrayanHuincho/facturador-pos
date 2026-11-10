<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>{{ $doc['titulo'] }} {{ $doc['numero'] }}</title>
@php
    $angosto = $ancho_mm < 70;
    $pt = fn ($n) => round($angosto ? $n * 0.88 : $n, 2) . 'pt';
@endphp
<style>
    @include('pdf.plantillas.parciales.fuentes')
    @page { margin: {{ $angosto ? '2.5mm 3mm 0 3mm' : '3mm 4mm 0 4mm' }}; }
    body { font-family: 'DejaVu Serif', serif; font-size: {{ $pt(7.4) }}; line-height: 1.28; color: #000; }
    .logo { max-width: 36mm; max-height: 13mm; margin-bottom: 1mm; }
    .razon { font-weight: bold; font-size: {{ $pt(10) }}; line-height: 1.2; }
    .lin { font-size: {{ $pt(6.8) }}; font-style: italic; }
    .doble { border-top: 3pt double #000; margin: 1.6mm 0; height: 0; }
    .tipo { font-weight: bold; font-size: {{ $pt(8.4) }}; letter-spacing: 0.8pt; text-transform: uppercase; }
    .num { font-size: {{ $pt(10.5) }}; font-weight: bold; }
    .par td { font-size: {{ $pt(7) }}; padding: 0.3pt 0; }
    .par td.e { font-style: italic; width: {{ $angosto ? '42%' : '32%' }}; padding-right: 1mm; }
    .par td.v { font-weight: bold; }
    .titulo-col th { font-style: italic; font-weight: normal; font-size: {{ $pt(6.8) }}; text-align: left; border-bottom: 0.6pt solid #000; padding-bottom: 0.4mm; }
    .titulo-col th.der { text-align: right; }
    .art td { font-size: {{ $pt(7) }}; padding-top: 0.8mm; }
    .cod { font-size: {{ $pt(6.2) }}; font-style: italic; }
    .tot td { font-size: {{ $pt(7.2) }}; padding: 0.3pt 0; }
    .gran td { font-weight: bold; font-size: {{ $pt(10.5) }}; padding-top: 0.8mm; }
    .letras { font-weight: bold; font-size: {{ $pt(6.9) }}; }
    .qr { width: {{ $angosto ? '29mm' : '35mm' }}; height: {{ $angosto ? '29mm' : '35mm' }}; }
    .rep { font-weight: bold; font-size: {{ $pt(6.7) }}; margin-top: 1mm; }
    .txt, .hash, .legal { font-size: {{ $pt(6.2) }}; font-style: italic; }
</style>
</head>
<body>
<div class="cen">
    @if($logo)<img class="logo" src="{{ $logo }}" alt=""><br>@endif
    <div class="razon">{{ $e['razon_social'] }}</div>
    @if($e['nombre_comercial'])<div class="lin">{{ $e['nombre_comercial'] }}</div>@endif
    @if($e['direccion'])<div class="lin">{{ $e['direccion'] }}</div>@endif
    @if($e['sucursal'])<div class="lin">Estab.: {{ $e['sucursal'] }}</div>@endif
    @if($contacto)<div class="lin">{{ implode(' · ', $contacto) }}</div>@endif
    <div class="doble"></div>
    <div class="lin">R.U.C. {{ $e['ruc'] }}</div>
    <div class="tipo">{{ $doc['titulo'] }}</div>
    <div class="num">N.º {{ $doc['numero'] }}</div>
    <div class="doble"></div>
</div>

<table class="par">
    @foreach($filas_cliente as $k => $v)<tr><td class="e">{{ $k }}</td><td class="v">{{ $v }}</td></tr>@endforeach
    @foreach($filas_documento as $k => $v)<tr><td class="e">{{ $k }}</td><td class="v">{{ $v }}</td></tr>@endforeach
</table>
<div class="doble"></div>

<table>
    <thead class="titulo-col"><tr><th>Descripción</th><th class="der">Importe</th></tr></thead>
    <tbody>
    @foreach($items as $i)
        <tr class="art"><td>{{ $i['descripcion'] }}@if($i['codigo'] || $i['afectacion'])<br><span class="cod">{{ trim($i['codigo'] . ' ' . $i['afectacion']) }}</span>@endif<br>{{ $i['cantidad'] }} {{ $i['unidad'] }} a {{ $i['precio_unitario'] }}</td><td class="der nowrap" style="vertical-align: bottom;">{{ $i['importe'] }}</td></tr>
    @endforeach
    </tbody>
</table>
<div class="doble"></div>

<table class="tot">
    @foreach($totales as $t)<tr><td>{{ $t['etiqueta'] }}</td><td class="der nowrap">{{ $doc['simbolo'] }} {{ $t['valor'] }}</td></tr>@endforeach
    <tr class="gran"><td>TOTAL</td><td class="der nowrap">{{ $doc['simbolo'] }} {{ $total }}</td></tr>
</table>
<div class="letras" style="margin-top: 1mm;">SON: {{ $letras_limpias }}</div>
@foreach($leyendas as $l)<div class="letras">{{ $l }}</div>@endforeach
@include('pdf.plantillas.parciales.adicionales', ['tam' => $pt(6.9), 'separacion' => '1.8mm'])

<div class="doble"></div>
<div class="cen">
    @if($qr)<img class="qr" src="{{ $qr }}" alt="">@endif
    @include('pdf.plantillas.parciales.textos-legales')
</div>
<div style="height: 2mm;"></div>
</body>
</html>
