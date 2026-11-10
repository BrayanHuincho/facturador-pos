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
    @font-face { font-family: 'Inter'; font-weight: normal; font-style: normal; src: url('{{ $fuentes }}/Inter-400.ttf') format('truetype'); }
    @font-face { font-family: 'Inter'; font-weight: bold; font-style: normal; src: url('{{ $fuentes }}/Inter-700.ttf') format('truetype'); }
    @font-face { font-family: 'InterSemi'; font-weight: normal; font-style: normal; src: url('{{ $fuentes }}/Inter-600.ttf') format('truetype'); }

    @page { margin: {{ $angosto ? '2.5mm 3mm 0 3mm' : '3mm 4mm 0 4mm' }}; }
    body, div, table, tr, td, th, img, span { margin: 0; padding: 0; }
    body { font-family: 'Inter', sans-serif; font-size: {{ $pt(7.6) }}; line-height: 1.24; color: #000; }
    table { border-collapse: collapse; width: 100%; }
    td, th { vertical-align: top; }
    .cen { text-align: center; }
    .der { text-align: right; }
    .b { font-weight: bold; }
    .semi { font-family: 'InterSemi', sans-serif; }
    .nowrap { white-space: nowrap; }
    .hr { border-top: 0.6pt dashed #000; margin: {{ $angosto ? '1.6mm' : '2mm' }} 0; height: 0; }
    .hr-solido { border-top: 0.8pt solid #000; margin: 1.6mm 0; height: 0; }

    .logo { max-width: {{ $angosto ? '34mm' : '46mm' }}; max-height: {{ $angosto ? '14mm' : '17mm' }}; margin-bottom: 1.4mm; }
    .razon { font-weight: bold; font-size: {{ $pt(9) }}; line-height: 1.2; }
    .comercial { font-family: 'InterSemi'; font-size: {{ $pt(7.6) }}; }
    .lin { font-size: {{ $pt(7) }}; margin-top: 0.5pt; }
    .doc { border: 0.8pt solid #000; border-radius: 3pt; margin-top: 1.8mm; padding: 1.2mm 1mm 1.3mm; text-align: center; }
    .doc .ruc { font-family: 'InterSemi'; font-size: {{ $pt(8) }}; }
    .doc .tipo { font-weight: bold; font-size: {{ $pt(8.4) }}; letter-spacing: 0.2pt; margin-top: 0.4mm; }
    .doc .num { font-weight: bold; font-size: {{ $pt(10) }}; letter-spacing: 0.3pt; }

    .datos td { font-size: {{ $pt(7.3) }}; padding: 0.35pt 0; }
    .datos td.e { width: {{ $angosto ? '31%' : '30%' }}; }
    .datos td.v { font-family: 'InterSemi'; }

    .items th { font-family: 'InterSemi'; font-weight: normal; font-size: {{ $pt(6.8) }}; text-align: left; padding-bottom: 0.6mm; }
    .items th.der { text-align: right; }
    .items td { font-size: {{ $pt(7.4) }}; padding-top: 0.9mm; }
    .items .cod { font-size: {{ $pt(6.6) }}; }
    .items .sub td { padding-top: 0.2mm; }

    .tot td { font-size: {{ $pt(7.5) }}; padding: 0.35pt 0; }
    .tot td.v { text-align: right; font-family: 'InterSemi'; white-space: nowrap; }
    .total td { font-weight: bold; font-size: {{ $pt(10) }}; padding-top: 1mm; }
    .letras { font-family: 'InterSemi'; font-size: {{ $pt(7.1) }}; }
    .pie { font-size: {{ $pt(6.8) }}; text-align: center; }
    .qr { width: {{ $angosto ? '32mm' : '38mm' }}; height: {{ $angosto ? '32mm' : '38mm' }}; }
    .hash { font-size: {{ $pt(6.6) }}; text-align: center; word-wrap: break-word; }
</style>
</head>
<body>

<div class="cen">
    @if($logo)<img class="logo" src="{{ $logo }}" alt=""><br>@endif
    <div class="razon">{{ $e['razon_social'] }}</div>
    @if($e['nombre_comercial'])<div class="comercial">{{ $e['nombre_comercial'] }}</div>@endif
    @if($e['direccion'])<div class="lin">{{ $e['direccion'] }}</div>@endif
    @if($e['sucursal'])<div class="lin">Estab.: {{ $e['sucursal'] }}</div>@endif
    @php $contacto = array_filter([$e['telefono'] ? 'Tel. ' . $e['telefono'] : null, $e['email']]); @endphp
    @if($contacto)<div class="lin">{{ implode(' · ', $contacto) }}</div>@endif
    <div class="doc">
        <div class="ruc">R.U.C. {{ $e['ruc'] }}</div>
        <div class="tipo">{{ $doc['titulo'] }}</div>
        <div class="num">{{ $doc['numero'] }}</div>
    </div>
</div>

<div class="hr"></div>
<table class="datos">
    <tr><td class="e">Emisión</td><td class="v">{{ $doc['fecha_emision'] }}  {{ $doc['hora_emision'] }}</td></tr>
    @if($doc['fecha_vencimiento'])<tr><td class="e">Vencimiento</td><td class="v">{{ $doc['fecha_vencimiento'] }}</td></tr>@endif
    <tr><td class="e">{{ $cli['etiqueta'] }}</td><td class="v">{{ $cli['nombre'] }}</td></tr>
    @if($cli['documento_numero'])<tr><td class="e">{{ $cli['documento_tipo'] }}</td><td class="v">{{ $cli['documento_numero'] }}</td></tr>@endif
    @if($cli['direccion'])<tr><td class="e">Dirección</td><td>{{ $cli['direccion'] }}</td></tr>@endif
    <tr><td class="e">Moneda</td><td class="v">{{ $doc['moneda'] }}</td></tr>
    @if(($doc['simbolo'] ?? 'S/') !== 'S/')<tr><td class="e">T.C.</td><td class="v">S/ {{ number_format($doc['tipo_cambio'] ?? 1, 3) }}</td></tr>@endif
    @if($doc['forma_pago'])<tr><td class="e">{{ $angosto ? 'Pago' : 'Forma de pago' }}</td><td class="v">{{ $doc['forma_pago'] }}</td></tr>@endif
    @if($doc['referencia'])<tr><td class="e">Referencia</td><td class="v">{{ $doc['referencia'] }}</td></tr>@endif
    @if(!empty($doc['orden_compra']))<tr><td class="e">O. compra</td><td class="v">{{ $doc['orden_compra'] }}</td></tr>@endif
    @if($doc['vendedor'])<tr><td class="e">Vendedor</td><td>{{ $doc['vendedor'] }}</td></tr>@endif
</table>

@if($ref)
    <div class="hr"></div>
    <table class="datos">
        <tr><td class="e">Modifica a</td><td class="v">{{ $ref['tipo'] }} {{ $ref['numero'] }}@if($ref['fecha']) del {{ $ref['fecha'] }}@endif</td></tr>
        @if($ref['motivo'])<tr><td class="e">Motivo</td><td class="v">{{ $ref['motivo'] }}</td></tr>@endif
    </table>
@endif

<div class="hr"></div>
@if($angosto)
    <table class="items">
        <thead><tr><th>Descripción</th><th class="der">Importe</th></tr><tr><td colspan="2" style="padding: 0;"><div class="hr" style="margin: 0;"></div></td></tr></thead>
        <tbody>
            @foreach($items as $i)
                <tr><td colspan="2">
                    @if($i['codigo'])<span class="cod">[{{ $i['codigo'] }}] </span>@endif{{ $i['descripcion'] }}@if($i['afectacion']) <span class="cod">({{ $i['afectacion'] }})</span>@endif
                </td></tr>
                <tr class="sub"><td>{{ $i['cantidad'] }} {{ $i['unidad'] }} x {{ $i['precio_unitario'] }}</td><td class="der semi nowrap">{{ $i['importe'] }}</td></tr>
            @endforeach
        </tbody>
    </table>
@else
    <table class="items">
        <thead><tr>
            <th style="width: 12mm;">Cant.</th>
            <th>Descripción</th>
            <th class="der" style="width: 13mm;">P. unit.</th>
            <th class="der" style="width: 15mm;">Importe</th>
        </tr><tr><td colspan="4" style="padding: 0;"><div class="hr" style="margin: 0;"></div></td></tr></thead>
        <tbody>
            @foreach($items as $i)
                <tr>
                    <td class="nowrap"><span class="semi">{{ $i['cantidad'] }}</span> <span class="cod">{{ $i['unidad'] }}</span></td>
                    <td>
                        @if($i['codigo'])<span class="cod">[{{ $i['codigo'] }}] </span>@endif{{ $i['descripcion'] }}@if($i['afectacion']) <span class="cod">({{ $i['afectacion'] }})</span>@endif
                    </td>
                    <td class="der nowrap">{{ $i['precio_unitario'] }}</td>
                    <td class="der semi nowrap">{{ $i['importe'] }}</td>
                </tr>
            @endforeach
        </tbody>
    </table>
@endif

<div class="hr"></div>
<table class="tot">
    @foreach($totales as $t)
        <tr><td>{{ $t['etiqueta'] }}</td><td class="v">{{ $doc['simbolo'] }} {{ $t['valor'] }}</td></tr>
    @endforeach
    <tr class="total"><td>TOTAL</td><td class="der nowrap">{{ $doc['simbolo'] }} {{ $total }}</td></tr>
</table>
<div class="letras" style="margin-top: 1.2mm;">{{ $letras }}</div>
@foreach($leyendas as $l)
    <div class="letras" style="margin-top: 0.8mm;">{{ $l }}</div>
@endforeach

@if($cuotas)
    <div class="hr"></div>
    <div class="semi">Crédito · {{ count($cuotas) }} {{ count($cuotas) === 1 ? 'cuota' : 'cuotas' }}</div>
    <table class="tot">
        @foreach($cuotas as $q)
            <tr><td>Cuota {{ $q['n'] }} · {{ $q['fecha'] }}</td><td class="v">{{ $doc['simbolo'] }} {{ $q['monto'] }}</td></tr>
        @endforeach
        <tr><td class="semi">Neto pendiente</td><td class="v">{{ $doc['simbolo'] }} {{ $pendiente }}</td></tr>
    </table>
@endif

@if($detraccion)
    <div class="hr"></div>
    <div class="semi">Operación sujeta al SPOT (detracción)</div>
    <table class="tot">
        @if($detraccion['bien'])<tr><td colspan="2">{{ $detraccion['bien'] }}</td></tr>@endif
        <tr><td>Detracción {{ $detraccion['porcentaje'] }}</td><td class="v">{{ $detraccion['monto'] }}</td></tr>
        @if($detraccion['cuenta'])<tr><td>Cta. Banco de la Nación</td><td class="v">{{ $detraccion['cuenta'] }}</td></tr>@endif
    </table>
@endif

@if($doc['observaciones'])
    <div class="hr"></div>
    <div><span class="semi">Obs.:</span> {!! nl2br(e($doc['observaciones'])) !!}</div>
@endif

@if($medios)
    <div class="hr"></div>
    @foreach($medios as $m)
        <div style="margin-bottom: 0.8mm; font-size: {{ $pt(7) }};">
            <span class="b">{{ $m['entidad'] }}</span> <span style="font-size: {{ $pt(6.4) }};">· {{ $m['subtitulo'] }}</span><br>
            @foreach($m['filas'] as $par){{ $par[0] }}: <span class="semi">{{ $par[1] }}</span>@if(!$loop->last)<br>@endif @endforeach
        </div>
    @endforeach
@endif

@unless($vista_previa && !$texto_legal)<div class="hr"></div>@endunless
@if($qr)
    <div class="cen"><img class="qr" src="{{ $qr }}" alt=""></div>
@endif
@if($hash)<div class="hash" style="margin-top: 0.8mm;">Hash: {{ $hash }}</div>@endif
@unless($vista_previa)
<div class="pie" style="margin-top: 1.2mm;">
    <span class="semi">{{ $representacion }}</span>
    <br>Consulte en e-consulta.sunat.gob.pe @if($consulta['web'])o {{ $consulta['web'] }}@endif
</div>
@endunless
@if($texto_legal)
    <div class="pie" style="margin-top: 1mm;">{!! nl2br(e($texto_legal)) !!}</div>
@endif
<div style="height: 2mm;"></div>
</body>
</html>
