<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>{{ $doc['titulo'] }} {{ $doc['numero'] }}</title>
<style>
    @font-face { font-family: 'Inter'; font-weight: normal; font-style: normal; src: url('{{ $fuentes }}/Inter-400.ttf') format('truetype'); }
    @font-face { font-family: 'Inter'; font-weight: bold; font-style: normal; src: url('{{ $fuentes }}/Inter-700.ttf') format('truetype'); }
    @page { margin: 3mm 4mm; }
    body, div, table, tr, td, th, img { margin: 0; padding: 0; }
    body { font-family: 'Inter', sans-serif; font-size: 7.4pt; line-height: 1.3; color: #000; }
    table { border-collapse: collapse; width: 100%; }
    td, th { vertical-align: top; }
    .cen { text-align: center; } .der { text-align: right; } .b { font-weight: bold; }
    .logo { max-width: 46mm; max-height: 18mm; }
    .sep { border-top: 0.7pt dashed #000; margin: 2mm 0; }
    .rot { font-weight: bold; font-size: 7pt; text-transform: uppercase; margin-bottom: 0.8mm; }
    .par td { padding: 0.3mm 0; }
    .par td.e { white-space: nowrap; width: 1%; padding-right: 1.5mm; }
    .items th { font-size: 6.8pt; text-align: left; border-bottom: 0.6pt solid #000; padding-bottom: 0.6mm; }
    .items td { padding: 0.8mm 0; border-bottom: 0.4pt dotted #555; }
    .qr { width: 28mm; height: 28mm; }
</style>
</head>
<body>
<div class="cen">
    @if($logo)<img class="logo" src="{{ $logo }}" alt=""><br>@endif
    <div class="b" style="font-size: 9pt;">{{ $e['razon_social'] }}</div>
    @if(!empty($e['nombre_comercial']))<div>{{ $e['nombre_comercial'] }}</div>@endif
    <div>R.U.C. {{ $e['ruc'] }}</div>
    @if(!empty($e['direccion']))<div>{{ $e['direccion'] }}</div>@endif
    <div class="sep"></div>
    <div class="b">{{ $doc['titulo'] }}</div>
    <div class="b" style="font-size: 10pt;">{{ $doc['numero'] }}</div>
</div>

@foreach($bloques as $b)
    <div class="sep"></div>
    <div class="rot">{{ $b['titulo'] }}</div>
    <table class="par">
        @foreach($b['pares'] as $par)
            <tr><td class="e">{{ $par[0] }}:</td><td>{{ $par[1] }}</td></tr>
        @endforeach
    </table>
@endforeach

<div class="sep"></div>
<table class="items">
    <thead><tr><th style="width: 12mm;">Cant.</th><th>Descripción</th></tr></thead>
    <tbody>
        @foreach($items as $i)
            <tr><td class="b">{{ $i['cantidad'] }} {{ $i['unidad'] }}</td><td>{{ $i['descripcion'] }}</td></tr>
        @endforeach
    </tbody>
</table>

@if($observaciones)
    <div class="sep"></div>
    <div><span class="b">Observaciones:</span> {{ $observaciones }}</div>
@endif

<div class="sep"></div>
<div class="cen">
    @if($qr)<img class="qr" src="{{ $qr }}" alt=""><br>@endif
    <div class="b">{{ $representacion }}</div>
    @if($hash)<div style="font-size: 6.4pt; margin-top: 1mm;">Hash: {{ $hash }}</div>@endif
</div>
</body>
</html>
