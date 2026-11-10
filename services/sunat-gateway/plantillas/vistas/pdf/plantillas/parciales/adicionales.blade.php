@php
    $titulo = "font-weight: bold; font-size: {$tam}; margin-top: {$separacion};";
    $celda = "font-size: {$tam}; padding: 0.5pt 0;";
@endphp
@if($cuotas)
    <div style="{{ $titulo }}">Crédito · {{ count($cuotas) }} {{ count($cuotas) === 1 ? 'cuota' : 'cuotas' }}</div>
    <table>
        @foreach($cuotas as $q)
            <tr><td style="{{ $celda }}">Cuota {{ $q['n'] }} · {{ $q['fecha'] }}</td><td class="der nowrap" style="{{ $celda }}">{{ $doc['simbolo'] }} {{ $q['monto'] }}</td></tr>
        @endforeach
        <tr><td style="{{ $celda }} font-weight: bold;">Neto pendiente</td><td class="der nowrap" style="{{ $celda }} font-weight: bold;">{{ $doc['simbolo'] }} {{ $pendiente }}</td></tr>
    </table>
@endif
@if($detraccion)
    <div style="{{ $titulo }}">Operación sujeta al SPOT (detracción)</div>
    <table>
        @if($detraccion['bien'])<tr><td colspan="2" style="{{ $celda }}">{{ $detraccion['bien'] }}</td></tr>@endif
        <tr><td style="{{ $celda }}">Detracción {{ $detraccion['porcentaje'] }}</td><td class="der nowrap" style="{{ $celda }}">{{ $detraccion['monto'] }}</td></tr>
        @if($detraccion['cuenta'])<tr><td style="{{ $celda }}">Cta. Banco de la Nación</td><td class="der nowrap" style="{{ $celda }}">{{ $detraccion['cuenta'] }}</td></tr>@endif
    </table>
@endif
@if($doc['observaciones'])
    <div style="{{ $titulo }}">Observaciones</div>
    <div style="{{ $celda }}">{!! nl2br(e($doc['observaciones'])) !!}</div>
@endif
@if($medios)
    <div style="{{ $titulo }}">Cuentas para pagos</div>
    @foreach($medios as $m)
        <div style="{{ $celda }}"><b>{{ $m['entidad'] }}</b> {{ $m['subtitulo'] ?? '' }}@foreach($m['filas'] as $par) · {{ $par[0] }}: {{ $par[1] }}@endforeach @if(!empty($m['nota'])) · {{ $m['nota'] }}@endif</div>
    @endforeach
@endif
