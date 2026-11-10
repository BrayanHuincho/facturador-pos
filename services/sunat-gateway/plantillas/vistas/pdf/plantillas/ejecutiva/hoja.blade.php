<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>{{ $doc['titulo'] }} {{ $doc['numero'] }}</title>
<style>
    @include('pdf.plantillas.parciales.fuentes')
    @page { margin: 10mm 15mm 13mm 15mm; }
    body { font-family: 'DejaVu Serif', serif; font-size: 8.4pt; line-height: 1.38; color: #1c1c1c; }
    .membrete { text-align: center; border-bottom: 3pt double {{ $c['acento'] }}; padding-bottom: 3mm; }
    .logo { max-width: 40mm; max-height: 16mm; margin-bottom: 1.5mm; }
    .razon { font-weight: bold; font-size: 13.5pt; letter-spacing: 0.6pt; color: {{ $c['acento'] }}; line-height: 1.2; }
    .lin { font-size: 8pt; margin-top: 0.8pt; font-style: italic; }
    .titulo { margin-top: 2.5mm; text-align: center; }
    .titulo .tipo { font-weight: bold; font-size: 12pt; letter-spacing: 1.8pt; text-transform: uppercase; color: {{ $c['acento'] }}; }
    .titulo .num { font-size: 12pt; margin-top: 0.5mm; }
    .titulo .ruc { font-size: 9pt; font-style: italic; }
    .ficha { margin-top: 3mm; border: 0.8pt solid {{ $c['acento'] }}; }
    .ficha td.lado { width: 50%; padding: 2.6mm 3.2mm; }
    .ficha td.lado + td.lado { border-left: 0.4pt solid {{ $c['acento'] }}; }
    .par td { padding: 0.8pt 0; font-size: 8.2pt; }
    .par td.e { font-style: italic; width: 26mm; color: #555; }
    .par td.v { font-weight: bold; }
    .items { margin-top: 3mm; border: 0.8pt solid {{ $c['acento'] }}; }
    .items th { background: {{ $c['acento'] }}; color: {{ $c['sobre'] }}; font-weight: bold; font-size: 7.6pt; padding: 1.8mm 1.6mm; text-align: left; border-left: 0.4pt solid #fff; }
    .items th.der { text-align: right; }
    .items td { padding: 1.2mm 1.6mm; font-size: 8.2pt; border-left: 0.4pt solid {{ $c['acento'] }}; border-top: 0.4pt solid {{ $c['acento'] }}; }
    .items tr { page-break-inside: avoid; }
    .cod { font-size: 7.2pt; font-style: italic; color: #555; }
    .fin { margin-top: 3mm; page-break-inside: avoid; }
    .caja-letras { border: 0.4pt solid {{ $c['acento'] }}; padding: 2.4mm 3mm; }
    .letras { font-weight: bold; }
    .leyenda { font-style: italic; font-size: 7.8pt; }
    .tot { border: 0.8pt solid {{ $c['acento'] }}; }
    .tot td { padding: 1.3mm 2.4mm; font-size: 8.4pt; border-top: 0.4pt solid {{ $c['acento'] }}; }
    .tot td.v { text-align: right; white-space: nowrap; font-weight: bold; }
    .tot tr.gran td { background: {{ $c['tinte'] }}; font-weight: bold; font-size: 11pt; border-top: 1.5pt solid {{ $c['acento'] }}; color: {{ $c['acento'] }}; white-space: nowrap; }
    .sunat { margin-top: 3mm; border-top: 3pt double {{ $c['acento'] }}; padding-top: 3mm; page-break-inside: avoid; }
    .sunat td { vertical-align: middle; }
    .qr { width: 24mm; height: 24mm; }
    .rep { font-weight: bold; font-size: 9pt; color: {{ $c['acento'] }}; }
    .txt, .hash, .legal { font-size: 7.6pt; margin-top: 0.8mm; font-style: italic; }
</style>
</head>
<body>
<div class="membrete">
    @if($logo)<img class="logo" src="{{ $logo }}" alt=""><br>@endif
    <div class="razon">{{ $e['razon_social'] }}</div>
    @if($e['nombre_comercial'])<div class="lin">{{ $e['nombre_comercial'] }}</div>@endif
    @if($e['direccion'])<div class="lin">{{ $e['direccion'] }}</div>@endif
    @if($e['sucursal'])<div class="lin">Establecimiento: {{ $e['sucursal'] }}</div>@endif
    @if($contacto)<div class="lin">{{ implode('  ·  ', $contacto) }}</div>@endif
</div>
<div class="titulo">
    <div class="tipo">{{ $doc['titulo'] }}</div>
    <div class="num">N.º {{ $doc['numero'] }}</div>
    <div class="ruc">R.U.C. {{ $e['ruc'] }}</div>
</div>

<table class="ficha"><tr>
    <td class="lado"><table class="par">@foreach($filas_cliente as $k => $v)<tr><td class="e">{{ $k }}</td><td class="v">{{ $v }}</td></tr>@endforeach</table></td>
    <td class="lado"><table class="par">@foreach($filas_documento as $k => $v)<tr><td class="e">{{ $k }}</td><td class="v">{{ $v }}</td></tr>@endforeach</table></td>
</tr></table>

<table class="items">
    <thead><tr>
        <th style="width: 8mm;">N.º</th>
        <th>Descripción</th>
        <th class="der" style="width: 14mm;">Cant.</th>
        <th style="width: 11mm;">Und.</th>
        <th class="der" style="width: 20mm;">P. unit.</th>
        @if($columnas['descuento'])<th class="der" style="width: 15mm;">Dscto.</th>@endif
        <th class="der" style="width: 22mm;">Importe</th>
    </tr></thead>
    <tbody>
    @foreach($items as $i)
        <tr>
            <td>{{ $i['n'] }}</td>
            <td>@if($i['codigo'])<div class="cod">{{ $i['codigo'] }}</div>@endif{!! nl2br(e($i['descripcion'])) !!}@if($i['afectacion'])<span class="cod"> ({{ $i['afectacion'] }})</span>@endif</td>
            <td class="der nowrap">{{ $i['cantidad'] }}</td>
            <td>{{ $i['unidad'] }}</td>
            <td class="der nowrap">{{ $i['precio_unitario'] }}</td>
            @if($columnas['descuento'])<td class="der nowrap">{{ $i['descuento'] }}</td>@endif
            <td class="der nowrap">{{ $i['importe'] }}</td>
        </tr>
    @endforeach
    </tbody>
</table>

<table class="fin"><tr>
    <td style="padding-right: 5mm;">
        <div class="caja-letras">
            <div class="letras">SON: {{ $letras_limpias }}</div>
            @foreach($leyendas as $l)<div class="leyenda">{{ $l }}</div>@endforeach
        </div>
        @include('pdf.plantillas.parciales.adicionales', ['tam' => '7.8pt', 'separacion' => '3mm'])
    </td>
    <td style="width: 70mm;">
        <table class="tot">
            @foreach($totales as $t)<tr><td>{{ $t['etiqueta'] }}</td><td class="v">{{ $doc['simbolo'] }} {{ $t['valor'] }}</td></tr>@endforeach
            <tr class="gran"><td>TOTAL</td><td class="der">{{ $doc['simbolo'] }} {{ $total }}</td></tr>
        </table>
    </td>
</tr></table>

@unless($vista_previa && !$texto_legal)
<div class="sunat"><table><tr>
    <td>@include('pdf.plantillas.parciales.textos-legales')</td>
    @if($qr)<td style="width: 26mm;" class="der"><img class="qr" src="{{ $qr }}" alt=""></td>@endif
</tr></table></div>
@endunless
</body>
</html>
