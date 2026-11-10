<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>{{ $doc['titulo'] }} {{ $doc['numero'] }}</title>
<style>
    @include('pdf.plantillas.parciales.fuentes')
    @page { margin: 14mm 18mm 14mm 18mm; }
    body { font-family: 'Inter', sans-serif; font-size: 8.8pt; line-height: 1.5; color: #333; }
    .num { font-size: 27pt; line-height: 1.1; color: #111; }
    .tipo { font-size: 9.5pt; color: #777; margin-bottom: 1mm; }
    .logo { max-width: 32mm; max-height: 14mm; margin-bottom: 2mm; }
    .razon { font-family: 'InterSemi'; font-size: 10pt; color: #111; }
    .gris { color: #777; font-size: 8.2pt; }
    .bloque { margin-top: 7mm; }
    .rotulo { font-size: 7.6pt; color: #999; margin-bottom: 1mm; }
    .par td { padding: 0.5pt 0; font-size: 8.6pt; color: #111; }
    .par td.e { color: #888; width: 28mm; }
    .items { margin-top: 7mm; }
    .items th { font-weight: normal; font-size: 7.6pt; color: #999; text-align: left; padding-bottom: 2mm; border-bottom: 0.4pt solid #bbb; }
    .items th.der { text-align: right; }
    .items td { padding: 1.8mm 0; font-size: 8.8pt; color: #111; border-bottom: 0.25pt solid #ddd; }
    .items td.sep { padding-left: 3mm; }
    .items tr { page-break-inside: avoid; }
    .cod { font-size: 7.4pt; color: #999; }
    .fin { margin-top: 5mm; page-break-inside: avoid; }
    .tot td { padding: 0.8mm 0; font-size: 8.8pt; }
    .tot td.v { text-align: right; color: #111; white-space: nowrap; }
    .gran td { padding-top: 3mm; font-size: 16pt; color: #111; white-space: nowrap; border-top: 0.4pt solid #bbb; }
    .letras { color: #111; }
    .leyenda { color: #777; font-size: 8pt; }
    .sunat { margin-top: 7mm; page-break-inside: avoid; }
    .qr { width: 21mm; height: 21mm; }
    .rep { color: #111; font-size: 8.4pt; }
    .txt, .hash, .legal { color: #888; font-size: 7.6pt; }
</style>
</head>
<body>
<table><tr>
    <td>
        <div class="tipo">{{ $doc['titulo'] }}</div>
        <div class="num">{{ $doc['numero'] }}</div>
    </td>
    <td class="der" style="width: 80mm;">
        @if($logo)<img class="logo" src="{{ $logo }}" alt=""><br>@endif
        <div class="razon">{{ $e['razon_social'] }}</div>
        <div class="gris">RUC {{ $e['ruc'] }}</div>
        @if($e['nombre_comercial'])<div class="gris">{{ $e['nombre_comercial'] }}</div>@endif
        @if($e['direccion'])<div class="gris">{{ $e['direccion'] }}</div>@endif
        @if($e['sucursal'])<div class="gris">{{ $e['sucursal'] }}</div>@endif
        @if($contacto)<div class="gris">{{ implode('  ', $contacto) }}</div>@endif
    </td>
</tr></table>

<table class="bloque"><tr>
    <td style="width: 52%; padding-right: 8mm;">
        <div class="rotulo">Para</div>
        <table class="par">@foreach($filas_cliente as $k => $v)<tr><td class="e">{{ $k }}</td><td>{{ $v }}</td></tr>@endforeach</table>
    </td>
    <td>
        <div class="rotulo">Información</div>
        <table class="par">@foreach($filas_documento as $k => $v)<tr><td class="e">{{ $k }}</td><td>{{ $v }}</td></tr>@endforeach</table>
    </td>
</tr></table>

<table class="items">
    <thead><tr>
        <th>Descripción</th>
        <th class="der" style="width: 17mm;">Cantidad</th>
        <th class="der" style="width: 22mm;">Precio</th>
        @if($columnas['descuento'])<th class="der" style="width: 16mm;">Dscto.</th>@endif
        <th class="der" style="width: 23mm;">Importe</th>
    </tr></thead>
    <tbody>
    @foreach($items as $i)
        <tr>
            <td>{!! nl2br(e($i['descripcion'])) !!}@if($i['codigo'] || $i['afectacion'])<br><span class="cod">{{ trim($i['codigo'] . ' ' . $i['afectacion']) }}</span>@endif</td>
            <td class="der nowrap">{{ $i['cantidad'] }} {{ $i['unidad'] }}</td>
            <td class="der nowrap">{{ $i['precio_unitario'] }}</td>
            @if($columnas['descuento'])<td class="der nowrap">{{ $i['descuento'] }}</td>@endif
            <td class="der nowrap">{{ $i['importe'] }}</td>
        </tr>
    @endforeach
    </tbody>
</table>

<table class="fin"><tr>
    <td style="padding-right: 12mm;">
        <div class="rotulo">Son</div>
        <div class="letras">{{ $letras_limpias }}</div>
        @foreach($leyendas as $l)<div class="leyenda">{{ $l }}</div>@endforeach
        @include('pdf.plantillas.parciales.adicionales', ['tam' => '8pt', 'separacion' => '4mm'])
    </td>
    <td style="width: 66mm;">
        <table class="tot">@foreach($totales as $t)<tr><td>{{ $t['etiqueta'] }}</td><td class="v">{{ $doc['simbolo'] }} {{ $t['valor'] }}</td></tr>@endforeach</table>
        <table class="gran"><tr><td>Total</td><td class="der">{{ $doc['simbolo'] }} {{ $total }}</td></tr></table>
    </td>
</tr></table>

@unless($vista_previa && !$texto_legal)
<table class="sunat"><tr>
    <td>@include('pdf.plantillas.parciales.textos-legales')</td>
    @if($qr)<td style="width: 21mm;"><img class="qr" src="{{ $qr }}" alt=""></td>@endif
</tr></table>
@endunless
</body>
</html>
