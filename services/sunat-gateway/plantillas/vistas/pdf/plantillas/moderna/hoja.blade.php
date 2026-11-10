<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>{{ $doc['titulo'] }} {{ $doc['numero'] }}</title>
<style>
    @include('pdf.plantillas.parciales.fuentes')
    @page { margin: 11mm 12mm 14mm 12mm; }
    body { font-family: 'Inter', sans-serif; font-size: 8.6pt; line-height: 1.35; color: {{ $c['texto'] }}; }
    .banda { background: {{ $c['acento'] }}; color: {{ $c['sobre'] }}; border-radius: 9pt; }
    .banda td { padding: 4mm 5mm; vertical-align: middle; }
    .logo { max-width: 34mm; max-height: 18mm; background: #fff; padding: 1mm; border-radius: 4pt; margin-bottom: 1.5mm; }
    .razon { font-weight: bold; font-size: 13pt; line-height: 1.15; }
    .lin { font-size: 8pt; margin-top: 1pt; }
    .tipo { font-family: 'InterSemi'; font-size: 9pt; letter-spacing: 0.8pt; text-transform: uppercase; }
    .num { font-weight: bold; font-size: 19pt; line-height: 1.2; }
    .ruc { font-size: 9.5pt; }
    .tarjetas { margin-top: 3.5mm; }
    .tarjeta { background: {{ $c['tinte'] }}; border-radius: 7pt; padding: 3.2mm 4mm; }
    .rotulo { font-family: 'InterSemi'; font-size: 7.2pt; letter-spacing: 0.8pt; text-transform: uppercase; color: {{ $c['acento'] }}; margin-bottom: 1.2mm; }
    .par td { font-size: 8.3pt; padding: 0.8pt 0; }
    .par td.e { color: {{ $c['suave'] }}; width: 26mm; }
    .par td.v { color: {{ $c['tinta'] }}; font-family: 'InterSemi'; }
    .items { margin-top: 4mm; }
    .items th { color: {{ $c['acento'] }}; font-family: 'InterSemi'; font-weight: normal; font-size: 7.6pt; letter-spacing: 0.4pt; text-transform: uppercase; text-align: left; padding: 0 1.8mm 2mm; border-bottom: 1.6pt solid {{ $c['acento'] }}; }
    .items th.der { text-align: right; }
    .items td { padding: 1.5mm 1.8mm; font-size: 8.6pt; color: {{ $c['tinta'] }}; }
    .items tr { page-break-inside: avoid; }
    .items tr.par-fila td { background: {{ $c['tinte'] }}; }
    .cod { font-size: 7.3pt; color: {{ $c['suave'] }}; }
    .imp { font-weight: bold; }
    .pie-tabla { margin-top: 3.5mm; page-break-inside: avoid; }
    .letras { font-family: 'InterSemi'; color: {{ $c['tinta'] }}; font-size: 8.8pt; }
    .leyenda { font-size: 7.8pt; margin-top: 1mm; }
    .tot td { padding: 1.3mm 3mm; font-size: 8.8pt; }
    .tot td.v { text-align: right; font-family: 'InterSemi'; color: {{ $c['tinta'] }}; white-space: nowrap; }
    .gran-total { margin-top: 1.5mm; background: {{ $c['acento'] }}; color: {{ $c['sobre'] }}; border-radius: 7pt; }
    .gran-total td { padding: 3.2mm 3.5mm; vertical-align: middle; }
    .gran-total .e { font-family: 'InterSemi'; font-size: 8.4pt; }
    .gran-total .v { text-align: right; font-weight: bold; font-size: 15pt; white-space: nowrap; }
    .sunat { margin-top: 4mm; background: {{ $c['tinte'] }}; border-radius: 7pt; page-break-inside: avoid; }
    .sunat td { padding: 3.5mm 4mm; vertical-align: middle; }
    .qr { width: 25mm; height: 25mm; }
    .rep { font-weight: bold; color: {{ $c['tinta'] }}; font-size: 9pt; }
    .txt, .hash, .legal { font-size: 7.8pt; margin-top: 1mm; }
</style>
</head>
<body>
<table class="banda"><tr>
    <td>
        @if($logo)<img class="logo" src="{{ $logo }}" alt=""><br>@endif
        <div class="razon">{{ $e['razon_social'] }}</div>
        @if($e['nombre_comercial'])<div class="lin">{{ $e['nombre_comercial'] }}</div>@endif
        @if($e['direccion'])<div class="lin">{{ $e['direccion'] }}</div>@endif
        @if($e['sucursal'])<div class="lin">Establecimiento: {{ $e['sucursal'] }}</div>@endif
        @if($contacto)<div class="lin">{{ implode('  ·  ', $contacto) }}</div>@endif
    </td>
    <td style="width: 66mm;" class="der">
        <div class="tipo">{{ $doc['titulo'] }}</div>
        <div class="num">{{ $doc['numero'] }}</div>
        <div class="ruc">R.U.C. {{ $e['ruc'] }}</div>
    </td>
</tr></table>

<table class="tarjetas"><tr>
    <td style="width: 54%; padding-right: 2mm;"><div class="tarjeta">
        <div class="rotulo">Cliente</div>
        <table class="par">@foreach($filas_cliente as $k => $v)<tr><td class="e">{{ $k }}</td><td class="v">{{ $v }}</td></tr>@endforeach</table>
    </div></td>
    <td style="padding-left: 2mm;"><div class="tarjeta">
        <div class="rotulo">Detalles</div>
        <table class="par">@foreach($filas_documento as $k => $v)<tr><td class="e">{{ $k }}</td><td class="v">{{ $v }}</td></tr>@endforeach</table>
    </div></td>
</tr></table>

<table class="items">
    <thead><tr>
        <th>Descripción</th>
        <th class="der" style="width: 15mm;">Cant.</th>
        <th style="width: 11mm;">Und.</th>
        <th class="der" style="width: 21mm;">P. unit.</th>
        @if($columnas['descuento'])<th class="der" style="width: 16mm;">Dscto.</th>@endif
        <th class="der" style="width: 23mm;">Importe</th>
    </tr></thead>
    <tbody>
    @foreach($items as $i)
        <tr class="{{ $loop->even ? 'par-fila' : '' }}">
            <td>@if($i['codigo'])<div class="cod">{{ $i['codigo'] }}</div>@endif{!! nl2br(e($i['descripcion'])) !!}@if($i['afectacion'])<span class="cod"> · {{ $i['afectacion'] }}</span>@endif</td>
            <td class="der nowrap">{{ $i['cantidad'] }}</td>
            <td>{{ $i['unidad'] }}</td>
            <td class="der nowrap">{{ $i['precio_unitario'] }}</td>
            @if($columnas['descuento'])<td class="der nowrap">{{ $i['descuento'] }}</td>@endif
            <td class="der nowrap imp">{{ $i['importe'] }}</td>
        </tr>
    @endforeach
    </tbody>
</table>

<table class="pie-tabla"><tr>
    <td style="padding-right: 6mm;">
        <div class="rotulo">Importe en letras</div>
        <div class="letras">SON: {{ $letras_limpias }}</div>
        @foreach($leyendas as $l)<div class="leyenda">{{ $l }}</div>@endforeach
        @include('pdf.plantillas.parciales.adicionales', ['tam' => '8pt', 'separacion' => '3mm'])
    </td>
    <td style="width: 74mm;">
        <table class="tot">@foreach($totales as $t)<tr><td>{{ $t['etiqueta'] }}</td><td class="v">{{ $doc['simbolo'] }} {{ $t['valor'] }}</td></tr>@endforeach</table>
        <table class="gran-total"><tr><td class="e">Importe total</td><td class="v">{{ $doc['simbolo'] }} {{ $total }}</td></tr></table>
    </td>
</tr></table>

@unless($vista_previa && !$texto_legal)
<table class="sunat"><tr>
    @if($qr)<td style="width: 30mm;"><img class="qr" src="{{ $qr }}" alt=""></td>@endif
    <td>@include('pdf.plantillas.parciales.textos-legales')</td>
</tr></table>
@endunless
</body>
</html>
