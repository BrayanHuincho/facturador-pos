<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>{{ $doc['titulo'] }} {{ $doc['numero'] }}</title>
@php
    $angosto = $ancho_mm < 70;
    $pt = fn ($n) => round($angosto ? $n * 0.9 : $n, 2) . 'pt';
@endphp
<style>
    @include('pdf.plantillas.parciales.fuentes')
    @page { margin: {{ $angosto ? '2.5mm 3mm 0 3mm' : '3mm 4mm 0 4mm' }}; }
    body { font-family: 'Inter', sans-serif; font-size: {{ $pt(7.8) }}; line-height: 1.26; color: #000; }
    .logo { max-width: {{ $angosto ? '32mm' : '42mm' }}; max-height: 14mm; margin-bottom: 1mm; }
    .razon { font-weight: bold; font-size: {{ $pt(10) }}; line-height: 1.15; }
    .lin { font-size: {{ $pt(7) }}; }
    .negro { background: #000; color: #fff; border-radius: 4pt; padding: 1.8mm 1.5mm; margin-top: 1.8mm; text-align: center; }
    .negro .tipo { font-family: 'InterSemi'; font-size: {{ $pt(8) }}; }
    .negro .num { font-weight: bold; font-size: {{ $pt(12) }}; }
    .negro .ruc { font-size: {{ $pt(7.6) }}; }
    .rotulo { font-weight: bold; font-size: {{ $pt(7.6) }}; margin-top: 2.2mm; border-bottom: 1.2pt solid #000; padding-bottom: 0.5mm; margin-bottom: 0.6mm; }
    .par td { font-size: {{ $pt(7.3) }}; padding: 0.3pt 0; }
    .par td.e { width: {{ $angosto ? '39%' : '30%' }}; padding-right: 1mm; }
    .par td.v { font-family: 'InterSemi'; }
    .art { padding-top: 1mm; font-size: {{ $pt(7.6) }}; }
    .sub td { font-size: {{ $pt(7.3) }}; }
    .imp { font-weight: bold; font-size: {{ $pt(8.2) }}; white-space: nowrap; }
    .cod { font-size: {{ $pt(6.6) }}; }
    .tot td { font-size: {{ $pt(7.6) }}; padding: 0.3pt 0; }
    .tot td.v { text-align: right; white-space: nowrap; font-family: 'InterSemi'; }
    .gran { background: #000; color: #fff; border-radius: 4pt; margin-top: 1.2mm; }
    .gran td { padding: 1.5mm 2mm; font-weight: bold; font-size: {{ $pt(10.5) }}; }
    .letras { margin-top: 1.2mm; font-family: 'InterSemi'; font-size: {{ $pt(7.1) }}; }
    .qr { width: {{ $angosto ? '30mm' : '36mm' }}; height: {{ $angosto ? '30mm' : '36mm' }}; margin-top: 2.2mm; }
    .pie { text-align: center; margin-top: 1mm; }
    .rep { font-family: 'InterSemi'; font-size: {{ $pt(6.9) }}; }
    .txt, .hash, .legal { font-size: {{ $pt(6.6) }}; margin-top: 0.5mm; }
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
</div>
<div class="negro">
    <div class="tipo">{{ $doc['titulo'] }}</div>
    <div class="num">{{ $doc['numero'] }}</div>
    <div class="ruc">R.U.C. {{ $e['ruc'] }}</div>
</div>

<div class="rotulo">Cliente</div>
<table class="par">@foreach($filas_cliente as $k => $v)<tr><td class="e">{{ $k }}</td><td class="v">{{ $v }}</td></tr>@endforeach</table>
<div class="rotulo">Datos</div>
<table class="par">@foreach($filas_documento as $k => $v)<tr><td class="e">{{ $k }}</td><td class="v">{{ $v }}</td></tr>@endforeach</table>

<div class="rotulo">Detalle</div>
@foreach($items as $i)
    <div class="art">@if($i['codigo'])<span class="cod">[{{ $i['codigo'] }}] </span>@endif{{ $i['descripcion'] }}@if($i['afectacion']) <span class="cod">({{ $i['afectacion'] }})</span>@endif</div>
    <table class="sub"><tr><td>{{ $i['cantidad'] }} {{ $i['unidad'] }} x {{ $i['precio_unitario'] }}</td><td class="der imp">{{ $i['importe'] }}</td></tr></table>
@endforeach

<div class="rotulo">Totales</div>
<table class="tot">@foreach($totales as $t)<tr><td>{{ $t['etiqueta'] }}</td><td class="v">{{ $doc['simbolo'] }} {{ $t['valor'] }}</td></tr>@endforeach</table>
<table class="gran"><tr><td>TOTAL</td><td class="der nowrap">{{ $doc['simbolo'] }} {{ $total }}</td></tr></table>
<div class="letras">SON: {{ $letras_limpias }}</div>
@foreach($leyendas as $l)<div class="letras">{{ $l }}</div>@endforeach
@include('pdf.plantillas.parciales.adicionales', ['tam' => $pt(7.2), 'separacion' => '2mm'])

@if($qr)<div class="cen"><img class="qr" src="{{ $qr }}" alt=""></div>@endif
<div class="pie">@include('pdf.plantillas.parciales.textos-legales')</div>
<div style="height: 2mm;"></div>
</body>
</html>
