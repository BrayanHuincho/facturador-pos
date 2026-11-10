@unless($vista_previa)
    <div class="rep">{{ $representacion }}</div>
    <div class="txt">Consulte su validez en e-consulta.sunat.gob.pe @if($consulta['web'])o en {{ $consulta['web'] }}@endif</div>
@endunless
@if($hash)<div class="hash partir">Código hash: {{ $hash }}</div>@endif
@if($texto_legal)<div class="legal">{!! nl2br(e($texto_legal)) !!}</div>@endif
