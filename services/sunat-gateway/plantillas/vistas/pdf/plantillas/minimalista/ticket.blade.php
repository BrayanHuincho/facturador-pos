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
    @page { margin: {{ $angosto ? '3mm 3.5mm 0 3.5mm' : '4mm 5mm 0 5mm' }}; }
    body { font-family: 'Inter', sans-serif; font-size: {{ $pt(7.8) }}; line-height: 1.34; color: #000; }
    .logo { max-width: 26mm; max-height: 11mm; margin-bottom: 1mm; }
    .num { font-size: {{ $pt(15) }}; line-height: 1.15; }
    .tipo, .lin { font-size: {{ $pt(7.2) }}; }
    .razon { font-family: 'InterSemi'; font-size: {{ $pt(8.4) }}; margin-top: 2mm; }
    .sep { margin-top: 3mm; }
    .par td { font-size: {{ $pt(7.4) }}; padding: 0.2pt 0; }
    .par td.e { width: {{ $angosto ? '39%' : '30%' }}; padding-right: 1mm; }
    .art { margin-top: 1.6mm; }
    .fila td { font-size: {{ $pt(7.4) }}; }
    .cod { font-size: {{ $pt(6.6) }}; }
    .tot td { font-size: {{ $pt(7.6) }}; padding: 0.2pt 0; }
    .gran td { font-size: {{ $pt(12) }}; padding-top: 1.4mm; }
    .qr { width: {{ $angosto ? '27mm' : '32mm' }}; height: {{ $angosto ? '27mm' : '32mm' }}; margin-top: 3mm; }
    .rep { font-size: {{ $pt(6.9) }}; margin-top: 1mm; }
    .txt, .hash, .legal { font-size: {{ $pt(6.5) }}; }
</style>
</head>
<body>
@if($logo)<img class="logo" src="{{ $logo }}" alt=""><br>@endif
<div class="tipo">{{ $doc['titulo'] }}</div>
<div class="num">{{ $doc['numero'] }}</div>
<div class="razon">{{ $e['razon_social'] }}</div>
<div class="lin">RUC {{ $e['ruc'] }}</div>
@if($e['nombre_comercial'])<div class="lin">{{ $e['nombre_comercial'] }}</div>@endif
@if($e['direccion'])<div class="lin">{{ $e['direccion'] }}</div>@endif
@if($e['sucursal'])<div class="lin">{{ $e['sucursal'] }}</div>@endif
@if($contacto)<div class="lin">{{ implode(' ', $contacto) }}</div>@endif

<table class="par sep">@foreach($filas_cliente as $k => $v)<tr><td class="e">{{ $k }}</td><td>{{ $v }}</td></tr>@endforeach</table>
<table class="par sep">@foreach($filas_documento as $k => $v)<tr><td class="e">{{ $k }}</td><td>{{ $v }}</td></tr>@endforeach</table>

<div class="sep"></div>
@foreach($items as $i)
    <div class="art">{{ $i['descripcion'] }}@if($i['codigo'] || $i['afectacion']) <span class="cod">{{ trim($i['codigo'] . ' ' . $i['afectacion']) }}</span>@endif</div>
    <table class="fila"><tr><td>{{ $i['cantidad'] }} {{ $i['unidad'] }} × {{ $i['precio_unitario'] }}</td><td class="der nowrap">{{ $i['importe'] }}</td></tr></table>
@endforeach

<table class="tot sep">@foreach($totales as $t)<tr><td>{{ $t['etiqueta'] }}</td><td class="der nowrap">{{ $doc['simbolo'] }} {{ $t['valor'] }}</td></tr>@endforeach</table>
<table class="gran"><tr><td>Total</td><td class="der nowrap">{{ $doc['simbolo'] }} {{ $total }}</td></tr></table>
<div class="sep">SON: {{ $letras_limpias }}</div>
@foreach($leyendas as $l)<div>{{ $l }}</div>@endforeach
@include('pdf.plantillas.parciales.adicionales', ['tam' => $pt(7.2), 'separacion' => '2.4mm'])

@if($qr)<img class="qr" src="{{ $qr }}" alt="">@endif
@include('pdf.plantillas.parciales.textos-legales')
<div style="height: 2mm;"></div>
</body>
</html>
