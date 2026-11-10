<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>{{ $doc['titulo'] }} {{ $doc['numero'] }}</title>
<style>
    @include('pdf.plantillas.parciales.fuentes')
    @page { margin: 7mm 8mm 9mm 8mm; }
    body { font-family: 'Inter', sans-serif; font-size: 7.2pt; line-height: 1.2; color: #111; }
    .mono { font-family: 'DejaVu Sans Mono', monospace; }
    .cabeza { border: 0.8pt solid #111; }
    .cabeza td { padding: 1.4mm 2mm; vertical-align: middle; }
    .cabeza td + td { border-left: 0.8pt solid #111; }
    .logo { max-width: 22mm; max-height: 11mm; }
    .razon { font-weight: bold; font-size: 9.5pt; }
    .lin { font-size: 6.8pt; }
    .tipo { font-weight: bold; font-size: 8pt; }
    .num { font-family: 'DejaVu Sans Mono', monospace; font-weight: bold; font-size: 11pt; }
    .tira { border: 0.8pt solid #111; border-top: none; }
    .tira td { padding: 1mm 2mm; font-size: 7pt; }
    .tira b { font-family: 'InterSemi'; font-weight: normal; color: #555; }
    .items { margin-top: 1.5mm; }
    .items th { background: #111; color: #fff; font-family: 'InterSemi'; font-weight: normal; font-size: 6.6pt; padding: 0.7mm 1mm; text-align: left; }
    .items th.der { text-align: right; }
    .items td { padding: 0.5mm 1mm; font-size: 7pt; border-bottom: 0.25pt solid #999; }
    .items tr { page-break-inside: avoid; }
    .items td.mono { font-size: 6.8pt; }
    .inferior { margin-top: 1.5mm; border: 0.8pt solid #111; page-break-inside: avoid; }
    .inferior > tbody > tr > td { padding: 1.5mm 2mm; }
    .inferior > tbody > tr > td + td { border-left: 0.8pt solid #111; }
    .qr { width: 19mm; height: 19mm; }
    .letras { font-weight: bold; font-size: 7.2pt; }
    .leyenda, .txt, .hash, .legal { font-size: 6.5pt; }
    .rep { font-weight: bold; font-size: 6.9pt; margin-top: 0.8mm; }
    .tot td { font-size: 7.2pt; padding: 0.15mm 0; }
    .gran td { font-weight: bold; font-size: 10pt; border-top: 0.8pt solid #111; padding-top: 0.6mm; white-space: nowrap; }
</style>
</head>
<body>
<table class="cabeza"><tr>
    @if($logo)<td style="width: 24mm;"><img class="logo" src="{{ $logo }}" alt=""></td>@endif
    <td>
        <div class="razon">{{ $e['razon_social'] }}@if($e['nombre_comercial']) <span class="lin">({{ $e['nombre_comercial'] }})</span>@endif</div>
        <div class="lin">{{ implode(' · ', array_filter([$e['direccion'], $e['sucursal'], ...$contacto])) }}</div>
    </td>
    <td style="width: 58mm;" class="cen">
        <div class="lin">R.U.C. {{ $e['ruc'] }}</div>
        <div class="tipo">{{ $doc['titulo'] }}</div>
        <div class="num">{{ $doc['numero'] }}</div>
    </td>
</tr></table>
<table class="tira"><tr>
    <td>@foreach($filas_cliente as $k => $v)<b>{{ $k }}:</b> {{ $v }}@if(!$loop->last) &nbsp;|&nbsp; @endif @endforeach</td>
</tr><tr>
    <td style="border-top: 0.25pt solid #999;">@foreach($filas_documento as $k => $v)<b>{{ $k }}:</b> {{ $v }}@if(!$loop->last) &nbsp;|&nbsp; @endif @endforeach</td>
</tr></table>

<table class="items">
    <thead><tr>
        <th style="width: 18mm;">Código</th>
        <th>Descripción</th>
        <th class="der" style="width: 18mm;">Cantidad</th>
        <th class="der" style="width: 19mm;">P. unit.</th>
        @if($columnas['descuento'])<th class="der" style="width: 15mm;">Dscto.</th>@endif
        <th class="der" style="width: 21mm;">Importe</th>
    </tr></thead>
    <tbody>
    @foreach($items as $i)
        <tr>
            <td class="mono">{{ $i['codigo'] }}</td>
            <td>{!! nl2br(e($i['descripcion'])) !!}@if($i['afectacion']) ({{ $i['afectacion'] }})@endif</td>
            <td class="der mono nowrap">{{ $i['cantidad'] }} {{ $i['unidad'] }}</td>
            <td class="der mono nowrap">{{ $i['precio_unitario'] }}</td>
            @if($columnas['descuento'])<td class="der mono nowrap">{{ $i['descuento'] }}</td>@endif
            <td class="der mono nowrap">{{ $i['importe'] }}</td>
        </tr>
    @endforeach
    </tbody>
</table>

<table class="inferior"><tr>
    @if($qr)<td style="width: 21mm;"><img class="qr" src="{{ $qr }}" alt=""></td>@endif
    <td>
        <div class="letras">SON: {{ $letras_limpias }}</div>
        @foreach($leyendas as $l)<div class="leyenda">{{ $l }}</div>@endforeach
        @include('pdf.plantillas.parciales.adicionales', ['tam' => '6.8pt', 'separacion' => '1.2mm'])
        @unless($vista_previa && !$texto_legal)
            @include('pdf.plantillas.parciales.textos-legales')
        @endunless
    </td>
    <td style="width: 58mm;">
        <table class="tot">@foreach($totales as $t)<tr><td>{{ $t['etiqueta'] }}</td><td class="der mono nowrap">{{ $doc['simbolo'] }} {{ $t['valor'] }}</td></tr>@endforeach</table>
        <table class="gran"><tr><td>TOTAL</td><td class="der mono">{{ $doc['simbolo'] }} {{ $total }}</td></tr></table>
    </td>
</tr></table>
</body>
</html>
