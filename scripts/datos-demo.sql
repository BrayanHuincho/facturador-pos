set client_encoding = 'UTF8';

begin;

create function pg_temp.demo_id(grupo int, numero int) returns uuid
language sql immutable as $$
  select ('de000000-0000-4000-8000-' || lpad(grupo::text, 4, '0') || lpad(numero::text, 8, '0'))::uuid
$$;

create function pg_temp.demo_ruc(base text) returns text
language plpgsql immutable as $$
declare
  pesos int[] := array[5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
  suma int := 0;
  resto int;
begin
  for i in 1..10 loop
    suma := suma + substr(base, i, 1)::int * pesos[i];
  end loop;
  resto := 11 - (suma % 11);
  return base || (case when resto = 10 then 0 when resto = 11 then 1 else resto end)::text;
end;
$$;

create function pg_temp.demo_menor_mil(n int) returns text
language plpgsql immutable as $$
declare
  unidades text[] := array['UNO','DOS','TRES','CUATRO','CINCO','SEIS','SIETE','OCHO','NUEVE','DIEZ','ONCE','DOCE','TRECE','CATORCE','QUINCE','DIECISEIS','DIECISIETE','DIECIOCHO','DIECINUEVE','VEINTE','VEINTIUNO','VEINTIDOS','VEINTITRES','VEINTICUATRO','VEINTICINCO','VEINTISEIS','VEINTISIETE','VEINTIOCHO','VEINTINUEVE'];
  decenas text[] := array['','','TREINTA','CUARENTA','CINCUENTA','SESENTA','SETENTA','OCHENTA','NOVENTA'];
  centenas text[] := array['CIENTO','DOSCIENTOS','TRESCIENTOS','CUATROCIENTOS','QUINIENTOS','SEISCIENTOS','SETECIENTOS','OCHOCIENTOS','NOVECIENTOS'];
  resto int := n % 100;
  c text;
  t text;
begin
  if n = 0 then return ''; end if;
  if n = 100 then return 'CIEN'; end if;
  c := case when n >= 100 then centenas[n / 100] else '' end;
  t := case
    when resto = 0 then ''
    when resto < 30 then unidades[resto]
    else decenas[resto / 10 - 1] || case when resto % 10 > 0 then ' Y ' || unidades[resto % 10] else '' end
  end;
  return trim(c || ' ' || t);
end;
$$;

create function pg_temp.demo_letras(monto numeric) returns text
language plpgsql immutable as $$
declare
  entero int := floor(monto)::int;
  centimos int := round((monto - floor(monto)) * 100)::int;
  miles int := entero / 1000;
  resto int := entero % 1000;
  texto text;
begin
  texto := case
    when entero = 0 then 'CERO'
    else trim(
      case when miles = 1 then 'MIL ' when miles > 1 then regexp_replace(pg_temp.demo_menor_mil(miles), 'UNO$', 'UN') || ' MIL ' else '' end
      || pg_temp.demo_menor_mil(resto))
  end;
  return 'SON: ' || texto || ' CON ' || lpad(centimos::text, 2, '0') || '/100 SOLES';
end;
$$;

insert into public.categorias (id, nombre, orden)
select pg_temp.demo_id(1, n::int), nombre, 10 + n::int
from unnest(array['Bebidas frías', 'Despensa', 'Snacks y dulces', 'Lácteos y huevos', 'Limpieza del hogar', 'Cuidado personal', 'Panadería', 'Bazar y hogar']) with ordinality as t(nombre, n)
on conflict (id) do nothing;

insert into public.productos (id, codigo, codigo_barras, nombre, descripcion, categoria_id, unidad, precio, costo, afectacion, aplica_icbper, controla_stock, stock_minimo)
select pg_temp.demo_id(2, n::int), 'DM' || lpad(n::text, 3, '0'), '9990000' || lpad(n::text, 6, '0'), nombre, 'Producto de demostración',
       pg_temp.demo_id(1, categoria), unidad, precio, round(precio * 0.68, 2), afectacion, icbper, true, 6
from (
  select row_number() over () as n, v.* from (values
  ('Agua de manantial 625 ml', 1, 'NIU', 2.50, '10', false),
  ('Agua con gas 500 ml', 1, 'NIU', 3.00, '10', false),
  ('Refresco de naranja 500 ml', 1, 'NIU', 3.50, '10', false),
  ('Refresco de limón 1.5 L', 1, 'NIU', 7.50, '10', false),
  ('Refresco de cola 2 L', 1, 'NIU', 9.90, '10', false),
  ('Néctar de durazno 1 L', 1, 'NIU', 6.20, '10', false),
  ('Bebida de maracuyá 500 ml', 1, 'NIU', 3.20, '10', false),
  ('Bebida energética 250 ml', 1, 'NIU', 5.50, '10', false),
  ('Té helado de limón 500 ml', 1, 'NIU', 3.80, '10', false),
  ('Arroz superior 5 kg', 2, 'NIU', 22.90, '20', false),
  ('Azúcar rubia 1 kg', 2, 'NIU', 4.20, '10', false),
  ('Aceite vegetal 1 L', 2, 'NIU', 9.80, '10', false),
  ('Fideos tallarín 500 g', 2, 'NIU', 3.60, '10', false),
  ('Lenteja seca 500 g', 2, 'NIU', 5.40, '20', false),
  ('Atún en trozos 170 g', 2, 'NIU', 6.90, '10', false),
  ('Sal de mesa 1 kg', 2, 'NIU', 1.80, '10', false),
  ('Harina sin preparar 1 kg', 2, 'NIU', 4.90, '10', false),
  ('Café instantáneo 100 g', 2, 'NIU', 14.50, '10', false),
  ('Avena en hojuelas 500 g', 2, 'NIU', 6.30, '10', false),
  ('Papas fritas clásicas 45 g', 3, 'NIU', 2.80, '10', false),
  ('Galletas de vainilla 120 g', 3, 'NIU', 2.50, '10', false),
  ('Chocolate con maní 40 g', 3, 'NIU', 3.40, '10', false),
  ('Caramelos surtidos 100 g', 3, 'NIU', 3.90, '10', false),
  ('Maní salado 90 g', 3, 'NIU', 4.10, '10', false),
  ('Barra de cereal 25 g', 3, 'NIU', 2.20, '10', false),
  ('Chicles de menta x 6', 3, 'NIU', 1.50, '10', false),
  ('Leche evaporada 400 g', 4, 'NIU', 4.60, '10', false),
  ('Yogur de fresa 1 L', 4, 'NIU', 8.90, '10', false),
  ('Queso fresco 500 g', 4, 'NIU', 13.90, '10', false),
  ('Mantequilla con sal 200 g', 4, 'NIU', 9.50, '10', false),
  ('Huevos pardos x 15', 4, 'NIU', 11.90, '20', false),
  ('Detergente en polvo 2 kg', 5, 'NIU', 18.90, '10', false),
  ('Lavavajilla líquido 500 ml', 5, 'NIU', 6.80, '10', false),
  ('Lejía tradicional 1 L', 5, 'NIU', 3.90, '10', false),
  ('Limpiador de pisos 900 ml', 5, 'NIU', 7.40, '10', false),
  ('Esponja de cocina x 3', 5, 'NIU', 4.50, '10', false),
  ('Papel higiénico x 12', 5, 'NIU', 16.90, '10', false),
  ('Bolsa de basura x 10', 5, 'NIU', 5.20, '10', false),
  ('Jabón de tocador 90 g', 6, 'NIU', 2.90, '10', false),
  ('Shampoo herbal 400 ml', 6, 'NIU', 15.90, '10', false),
  ('Pasta dental 75 ml', 6, 'NIU', 6.50, '10', false),
  ('Desodorante roll-on 50 ml', 6, 'NIU', 11.50, '10', false),
  ('Cepillo dental suave', 6, 'NIU', 4.80, '10', false),
  ('Toallas húmedas x 50', 6, 'NIU', 9.20, '10', false),
  ('Pan de molde blanco', 7, 'NIU', 7.90, '10', false),
  ('Pan integral rebanado', 7, 'NIU', 8.90, '10', false),
  ('Pan francés x 6', 7, 'NIU', 2.40, '10', false),
  ('Keke de vainilla 400 g', 7, 'NIU', 12.50, '10', false),
  ('Empanada de carne', 7, 'NIU', 4.50, '10', false),
  ('Tostadas integrales 200 g', 7, 'NIU', 5.90, '10', false),
  ('Bolsa plástica mediana', 8, 'NIU', 0.10, '10', true),
  ('Pilas alcalinas AA x 2', 8, 'NIU', 7.90, '10', false),
  ('Vela blanca x 6', 8, 'NIU', 5.60, '10', false),
  ('Fósforos caja x 10', 8, 'NIU', 2.00, '10', false),
  ('Foco LED 9 W', 8, 'NIU', 8.50, '10', false),
  ('Cinta de embalaje 48 mm', 8, 'NIU', 6.40, '10', false),
  ('Cuaderno rayado A4', 8, 'NIU', 6.90, '10', false),
  ('Lapicero azul x 3', 8, 'NIU', 3.50, '10', false),
  ('Taper hermético 1 L', 8, 'NIU', 12.90, '10', false),
  ('Olla de aluminio 24 cm', 8, 'NIU', 59.90, '10', false)
) as v(nombre, categoria, unidad, precio, afectacion, icbper)
) t
on conflict (id) do nothing;

insert into public.clientes (id, tipo_documento, numero_documento, nombre, direccion, telefono)
select pg_temp.demo_id(3, n::int), '6', pg_temp.demo_ruc('20999' || lpad(n::text, 5, '0')), nombre, 'Av. Inventada ' || (100 + n * 7) || ', Lima', '9000' || lpad((n * 137)::text, 5, '0')
from unnest(array[
  'Bodega Imaginaria del Sur S.A.C.', 'Distribuidora Ficticia Andina S.R.L.', 'Minimarket Ejemplo Central E.I.R.L.',
  'Comercial Demo Pacífico S.A.C.', 'Restaurante La Mesa Inventada S.A.C.', 'Ferretería Muestra Norte E.I.R.L.',
  'Inversiones Ficción Dorada S.A.C.', 'Servicios Ejemplares del Valle S.R.L.', 'Panadería El Horno Imaginario E.I.R.L.',
  'Librería Demo Letras S.A.C.', 'Farmacia Ficticia Salud S.R.L.', 'Hostal Muestra Colonial S.A.C.',
  'Transportes Inventados del Centro S.A.C.', 'Cafetería Demo Aroma E.I.R.L.'
]) with ordinality as t(nombre, n)
on conflict do nothing;

insert into public.clientes (id, tipo_documento, numero_documento, nombre, direccion, telefono)
select pg_temp.demo_id(3, 100 + n::int), '1', '99' || lpad((n * 1117)::text, 6, '0'), nombre, 'Jr. Ficticio ' || (200 + n * 3) || ', Lima', '9100' || lpad((n * 211)::text, 5, '0')
from unnest(array[
  'Rosa Ejemplo Mamani', 'Carlos Demo Flores', 'Lucía Ficticia Rojas', 'Jorge Muestra Quispe', 'Ana Inventada Torres',
  'Pedro Ejemplo Vargas', 'María Demo Castillo', 'Luis Ficticio Ramos', 'Elena Muestra Paredes', 'Raúl Inventado Díaz',
  'Sofía Ejemplo Chávez', 'Miguel Demo Herrera', 'Carmen Ficticia León', 'Andrés Muestra Salas', 'Julia Inventada Ríos',
  'Diego Ejemplo Campos', 'Teresa Demo Medina', 'Óscar Ficticio Vega', 'Patricia Muestra Cruz', 'Hugo Inventado Soto',
  'Gloria Ejemplo Núñez', 'Iván Demo Palacios', 'Rocío Ficticia Bravo', 'Marco Muestra Ayala', 'Silvia Inventada Pinto',
  'Fernando Ejemplo Luna'
]) with ordinality as t(nombre, n)
on conflict do nothing;

do $$
declare
  marcador constant uuid := pg_temp.demo_id(4, 1);
  v_entorno text;
  v_ruc text;
  v_est uuid;
  v_usr uuid;
  v_ahora timestamp := now() at time zone 'America/Lima';
  v_b int; v_f int; v_nv int; v_bc int; v_fc int; v_t int;
  v_b0 int; v_f0 int; v_nv0 int; v_bc0 int; v_fc0 int;
  v_momentos timestamp[];
  v_ts timestamp;
  v_n int := 0;
  v_tipo text; v_serie text; v_corr int;
  v_cid uuid; v_tid uuid; v_cli record;
  v_cli_id uuid; v_doc_tipo text; v_doc_num text; v_cli_nom text; v_cli_dir text;
  v_estado text;
  v_ids uuid[]; v_p record; v_orden int;
  v_cant numeric; v_desc numeric; v_imp numeric; v_base numeric; v_igv numeric; v_icb numeric;
  v_grav numeric; v_exo numeric; v_igv_t numeric; v_icb_t numeric; v_desc_t numeric; v_total numeric;
  v_medio text; v_azar float; v_mixto numeric; v_recibido numeric; v_vuelto numeric;
  v_hash text;
  r record;
  v_con_cliente boolean;
begin
  if exists (select 1 from public.comprobantes where id = marcador) then
    raise notice 'Los datos demo ya estaban cargados: no se insertó ningún documento.';
    return;
  end if;

  select entorno into v_entorno from public.configuracion_sunat where id = 1;
  if v_entorno is distinct from 'beta' then
    raise exception 'Los datos demo solo se cargan en entorno beta.';
  end if;
  select ruc into v_ruc from public.empresa where id = 1;
  if v_ruc is null then
    raise exception 'Configura la empresa antes de cargar los datos demo.';
  end if;
  select id into v_est from public.establecimientos where activo order by (codigo = '0000') desc, creado_en limit 1;
  select id into v_usr from public.perfiles where activo order by (rol = 'admin') desc, creado_en limit 1;
  if v_est is null or v_usr is null then
    raise exception 'Faltan un establecimiento o un usuario activos.';
  end if;

  select ultimo into strict v_b from public.series where tipo = '03' and serie = 'B001' for update;
  select ultimo into strict v_f from public.series where tipo = '01' and serie = 'F001' for update;
  select ultimo into strict v_nv from public.series where tipo = 'NV' and serie = 'NV01' for update;
  select ultimo into strict v_bc from public.series where tipo = '07' and serie = 'BC01' for update;
  select ultimo into strict v_fc from public.series where tipo = '07' and serie = 'FC01' for update;
  select ultimo into strict v_t from public.series where tipo = '09' and serie = 'T001' for update;
  v_b0 := v_b; v_f0 := v_f; v_nv0 := v_nv; v_bc0 := v_bc; v_fc0 := v_fc;

  perform setseed(0.4242);

  select array_agg(m order by m) into v_momentos
  from (
    select least(
      (v_ahora::date - (floor(random() * 90))::int) + time '08:00' + (random() * interval '12 hours 30 minutes'),
      v_ahora - interval '5 minutes'
    ) as m
    from generate_series(1, 290)
  ) s;

  foreach v_ts in array v_momentos loop
    v_n := v_n + 1;
    v_azar := random();
    if v_azar < 0.52 then
      v_tipo := '03'; v_serie := 'B001'; v_b := v_b + 1; v_corr := v_b;
    elsif v_azar < 0.74 then
      v_tipo := '01'; v_serie := 'F001'; v_f := v_f + 1; v_corr := v_f;
    else
      v_tipo := 'NV'; v_serie := 'NV01'; v_nv := v_nv + 1; v_corr := v_nv;
    end if;

    v_cid := pg_temp.demo_id(4, v_n);
    v_tid := pg_temp.demo_id(5, (v_ts::date - date '2020-01-01'));
    insert into public.turnos_caja (id, establecimiento_id, usuario_id, estado, abierto_en, cerrado_en, monto_apertura)
    values (v_tid, v_est, v_usr, 'cerrado',
            (v_ts::date + time '07:45') at time zone 'America/Lima',
            least((v_ts::date + time '21:00') at time zone 'America/Lima', now()), 150)
    on conflict (id) do nothing;

    v_grav := 0; v_exo := 0; v_igv_t := 0; v_icb_t := 0; v_desc_t := 0; v_total := 0; v_orden := 0;
    select array(select id from public.productos where id::text like 'de000000-0000-4000-8000-0002%' order by random()
                 limit (case when v_tipo = '01' then 2 + floor(random() * 5)::int else 1 + floor(random() * 4)::int end))
      into v_ids;

    v_con_cliente := true;
    v_cli_id := null; v_doc_tipo := '0'; v_doc_num := null; v_cli_nom := 'CLIENTES VARIOS'; v_cli_dir := null;
    if v_tipo = '01' then
      select id, tipo_documento, numero_documento, nombre, direccion into v_cli from public.clientes
       where id::text like 'de000000-0000-4000-8000-0003%' and tipo_documento = '6' order by random() limit 1;
    elsif random() < 0.55 then
      select id, tipo_documento, numero_documento, nombre, direccion into v_cli from public.clientes
       where id::text like 'de000000-0000-4000-8000-0003%' and tipo_documento = '1' order by random() limit 1;
    else
      v_con_cliente := false;
    end if;

    if v_con_cliente then
      v_cli_id := v_cli.id; v_doc_tipo := v_cli.tipo_documento; v_doc_num := v_cli.numero_documento;
      v_cli_nom := v_cli.nombre; v_cli_dir := v_cli.direccion;
    end if;

    v_estado := case when random() < 0.03 then 'anulado' when v_tipo = 'NV' then 'no_aplica' else 'aceptado' end;

    insert into public.comprobantes (id, establecimiento_id, turno_id, usuario_id, tipo, serie, correlativo, fecha_emision, hora_emision, moneda, forma_pago,
      cliente_id, cliente_tipo_documento, cliente_numero_documento, cliente_nombre, cliente_direccion, estado, entorno, creado_en)
    values (v_cid, v_est, v_tid, v_usr, v_tipo, v_serie, v_corr, v_ts::date, v_ts::time, 'PEN', 'contado',
      v_cli_id, v_doc_tipo, v_doc_num, v_cli_nom, v_cli_dir, v_estado, 'beta', v_ts at time zone 'America/Lima');

    for v_p in select * from public.productos p where p.id = any(v_ids) loop
      v_orden := v_orden + 1;
      v_cant := case when random() < 0.62 then 1 when random() < 0.7 then 2 else 3 + floor(random() * 4) end;
      v_desc := case when random() < 0.08 then round(v_cant * v_p.precio * 0.05, 2) else 0 end;
      v_imp := round(v_cant * v_p.precio, 2) - v_desc;
      if v_p.afectacion = '10' then
        v_base := round(v_imp / 1.18, 2);
        v_igv := v_imp - v_base;
        v_grav := v_grav + v_base;
      else
        v_base := v_imp;
        v_igv := 0;
        v_exo := v_exo + v_base;
      end if;
      v_icb := case when v_p.aplica_icbper then round(v_cant * 0.5, 2) else 0 end;
      v_igv_t := v_igv_t + v_igv;
      v_icb_t := v_icb_t + v_icb;
      v_desc_t := v_desc_t + v_desc;
      v_total := v_total + v_base + v_igv + v_icb;
      insert into public.comprobante_items (comprobante_id, producto_id, orden, codigo, descripcion, unidad, cantidad, precio_unitario, valor_unitario, descuento, afectacion, base, igv, icbper, total)
      values (v_cid, v_p.id, v_orden, v_p.codigo, v_p.nombre, v_p.unidad, v_cant,
              case when v_desc > 0 then round((v_base + v_igv) / v_cant, 6) else v_p.precio end,
              case when v_p.afectacion = '10' then round(v_p.precio / 1.18, 6) else v_p.precio end,
              v_desc, v_p.afectacion, v_base, v_igv, v_icb, v_base + v_igv + v_icb);
    end loop;

    if v_tipo = '03' and v_total >= 700 and v_cli_id is null then
      select id, tipo_documento, numero_documento, nombre, direccion into v_cli from public.clientes
       where id::text like 'de000000-0000-4000-8000-0003%' and tipo_documento = '1' order by random() limit 1;
      update public.comprobantes set cliente_id = v_cli.id, cliente_tipo_documento = v_cli.tipo_documento, cliente_numero_documento = v_cli.numero_documento, cliente_nombre = v_cli.nombre, cliente_direccion = v_cli.direccion where id = v_cid;
      v_doc_tipo := v_cli.tipo_documento; v_doc_num := v_cli.numero_documento;
    end if;

    v_azar := random();
    v_medio := case
      when v_tipo = '01' and v_azar < 0.45 then 'transferencia'
      when v_tipo = '01' and v_azar < 0.60 then 'deposito'
      when v_azar < 0.45 then 'efectivo'
      when v_azar < 0.68 then 'yape'
      when v_azar < 0.78 then 'plin'
      when v_azar < 0.92 then 'tarjeta'
      else 'efectivo'
    end;

    v_recibido := v_total; v_vuelto := 0;
    if v_medio = 'efectivo' and v_total >= 8 and random() < 0.14 then
      v_mixto := round(v_total * 0.5, 2);
      insert into public.pagos (comprobante_id, medio, monto) values (v_cid, 'efectivo', v_mixto), (v_cid, 'yape', v_total - v_mixto);
    else
      if v_medio = 'efectivo' then
        v_recibido := ceil(v_total / 5) * 5;
        v_vuelto := v_recibido - v_total;
      end if;
      insert into public.pagos (comprobante_id, medio, monto, referencia)
      values (v_cid, v_medio, v_total, case when v_medio in ('transferencia', 'deposito') then 'OP-DEMO-' || lpad(v_n::text, 6, '0') end);
    end if;

    v_hash := encode(decode(md5(v_cid::text), 'hex'), 'base64');
    update public.comprobantes set
      op_gravadas = v_grav, op_exoneradas = v_exo, descuento_total = v_desc_t, igv = v_igv_t, icbper = v_icb_t, total = v_total,
      recibido = v_recibido, vuelto = v_vuelto,
      leyendas = jsonb_build_array(jsonb_build_object('code', '1000', 'value', pg_temp.demo_letras(v_total))),
      sunat_codigo = case when v_tipo = 'NV' then null else '0' end,
      sunat_descripcion = case when v_estado = 'anulado' then 'Anulado en el sistema: dato de demostración' when v_tipo = 'NV' then null else 'Documento de demostración, no enviado a SUNAT' end,
      hash = case when v_tipo = 'NV' then null else v_hash end,
      qr = case when v_tipo = 'NV' then null else concat_ws('|', v_ruc, v_tipo, v_serie, lpad(v_corr::text, 8, '0'), v_igv_t, v_total, v_ts::date, v_doc_tipo, coalesce(v_doc_num, '-'), v_hash) end
    where id = v_cid;
  end loop;

  for r in
    select * from (
      select c.* from public.comprobantes c
       where c.id::text like 'de000000-0000-4000-8000-0004%' and c.estado = 'aceptado' and c.tipo in ('01', '03')
       order by random() limit 12
    ) s
    order by s.fecha_emision, s.hora_emision
  loop
    v_n := v_n + 1;
    v_ts := least(r.fecha_emision + time '09:00' + (random() * interval '10 hours') + (1 + floor(random() * 3))::int * interval '1 day', v_ahora - interval '3 minutes');
    if v_ts < (r.fecha_emision + r.hora_emision) then
      v_ts := r.fecha_emision + r.hora_emision;
    end if;
    if r.tipo = '01' then
      v_serie := 'FC01'; v_fc := v_fc + 1; v_corr := v_fc;
    else
      v_serie := 'BC01'; v_bc := v_bc + 1; v_corr := v_bc;
    end if;
    v_cid := pg_temp.demo_id(4, v_n);
    v_tid := pg_temp.demo_id(5, (v_ts::date - date '2020-01-01'));
    insert into public.turnos_caja (id, establecimiento_id, usuario_id, estado, abierto_en, cerrado_en, monto_apertura)
    values (v_tid, v_est, v_usr, 'cerrado',
            (v_ts::date + time '07:45') at time zone 'America/Lima',
            least((v_ts::date + time '21:00') at time zone 'America/Lima', now()), 150)
    on conflict (id) do nothing;
    v_hash := encode(decode(md5(v_cid::text), 'hex'), 'base64');
    insert into public.comprobantes (id, establecimiento_id, turno_id, usuario_id, tipo, serie, correlativo, fecha_emision, hora_emision, moneda, forma_pago,
      cliente_id, cliente_tipo_documento, cliente_numero_documento, cliente_nombre, cliente_direccion,
      op_gravadas, op_exoneradas, op_inafectas, op_gratuitas, descuento_total, igv, icbper, total, recibido, vuelto, leyendas,
      afectado_id, afectado_tipo, afectado_serie, afectado_correlativo, motivo_codigo, motivo_descripcion,
      estado, sunat_codigo, sunat_descripcion, hash, qr, entorno, creado_en)
    values (v_cid, v_est, v_tid, v_usr, '07', v_serie, v_corr, v_ts::date, v_ts::time, 'PEN', 'contado',
      r.cliente_id, r.cliente_tipo_documento, r.cliente_numero_documento, r.cliente_nombre, r.cliente_direccion,
      r.op_gravadas, r.op_exoneradas, r.op_inafectas, r.op_gratuitas, r.descuento_total, r.igv, r.icbper, r.total, r.total, 0, r.leyendas,
      r.id, r.tipo, r.serie, r.correlativo, '01', 'Anulación de la operación',
      'aceptado', '0', 'Documento de demostración, no enviado a SUNAT', v_hash,
      concat_ws('|', v_ruc, '07', v_serie, lpad(v_corr::text, 8, '0'), r.igv, r.total, v_ts::date, r.cliente_tipo_documento, coalesce(r.cliente_numero_documento, '-'), v_hash),
      'beta', v_ts at time zone 'America/Lima');
    insert into public.comprobante_items (comprobante_id, producto_id, orden, codigo, descripcion, unidad, cantidad, precio_unitario, valor_unitario, descuento, afectacion, base, igv, icbper, total)
      select v_cid, producto_id, orden, codigo, descripcion, unidad, cantidad, precio_unitario, valor_unitario, descuento, afectacion, base, igv, icbper, total
        from public.comprobante_items where comprobante_id = r.id;
    insert into public.pagos (comprobante_id, medio, monto, referencia)
      select v_cid, medio, monto, referencia from public.pagos where comprobante_id = r.id;
  end loop;

  insert into public.stock (producto_id, establecimiento_id, cantidad)
  select p.id, v_est, case when random() < 0.08 then floor(random() * 5) else 12 + floor(random() * 140) end
    from public.productos p
   where p.id::text like 'de000000-0000-4000-8000-0002%'
  on conflict (producto_id, establecimiento_id) do nothing;

  insert into public.movimientos_stock (producto_id, establecimiento_id, tipo, cantidad, referencia_id, usuario_id, creado_en)
  select i.producto_id, c.establecimiento_id, 'venta', -i.cantidad, c.id, c.usuario_id, c.creado_en
    from public.comprobante_items i
    join public.comprobantes c on c.id = i.comprobante_id
   where c.id::text like 'de000000-0000-4000-8000-0004%' and c.tipo <> '07';

  insert into public.movimientos_stock (producto_id, establecimiento_id, tipo, cantidad, referencia_id, usuario_id, creado_en)
  select i.producto_id, c.establecimiento_id, 'anulacion', i.cantidad, c.id, c.usuario_id, c.creado_en + interval '2 hours'
    from public.comprobante_items i
    join public.comprobantes c on c.id = i.comprobante_id
   where c.id::text like 'de000000-0000-4000-8000-0004%' and c.estado = 'anulado';

  insert into public.movimientos_stock (producto_id, establecimiento_id, tipo, cantidad, referencia_id, usuario_id, creado_en)
  select s.producto_id, s.establecimiento_id, 'compra',
         s.cantidad - coalesce((select sum(m.cantidad) from public.movimientos_stock m where m.producto_id = s.producto_id), 0),
         null, v_usr, now() - interval '95 days'
    from public.stock s
   where s.producto_id::text like 'de000000-0000-4000-8000-0002%';

  insert into public.movimientos_caja (turno_id, tipo, monto, concepto, usuario_id, creado_en)
  select t.id, case when g % 3 = 0 then 'ingreso' else 'egreso' end,
         round((10 + random() * 90)::numeric, 2),
         case when g % 3 = 0 then 'Aporte para sencillo' else (array['Compra de bolsas', 'Pago de delivery', 'Útiles de limpieza'])[1 + (g % 3)::int] end,
         v_usr, t.abierto_en + interval '4 hours'
    from (select id, abierto_en, row_number() over (order by abierto_en) as g from public.turnos_caja where id::text like 'de000000-0000-4000-8000-0005%') t
   where t.g % 4 = 0;

  update public.turnos_caja t set
    monto_esperado = t.monto_apertura + e.efectivo + e.movimientos,
    monto_contado = t.monto_apertura + e.efectivo + e.movimientos + e.ajuste,
    diferencia = e.ajuste,
    observacion = 'Turno de demostración'
  from (
    select tc.id,
           coalesce((select sum(case when c.tipo = '07' then -p.monto else p.monto end)
                       from public.pagos p join public.comprobantes c on c.id = p.comprobante_id
                      where c.turno_id = tc.id and p.medio = 'efectivo' and c.estado not in ('anulado', 'por_anular')), 0) as efectivo,
           coalesce((select sum(case when m.tipo = 'ingreso' then m.monto else -m.monto end)
                       from public.movimientos_caja m where m.turno_id = tc.id), 0) as movimientos,
           (case when random() < 0.15 then round((random() * 4 - 2)::numeric, 2) else 0 end)::numeric as ajuste
      from public.turnos_caja tc
     where tc.id::text like 'de000000-0000-4000-8000-0005%'
  ) e
  where t.id = e.id;

  for r in select g as n, (array['aceptado', 'aceptado', 'anulado'])[g] as estado, pg_temp.demo_id(6, g) as id,
                  (select numero_documento from public.clientes where id = pg_temp.demo_id(3, g)) as doc,
                  (select nombre from public.clientes where id = pg_temp.demo_id(3, g)) as nombre
             from generate_series(1, 3) g
  loop
    v_t := v_t + 1;
    insert into public.guias_remision (id, establecimiento_id, usuario_id, serie, correlativo, fecha_emision, fecha_traslado, motivo_codigo, modalidad, peso_total, unidad_peso, bultos,
      partida_ubigeo, partida_direccion, llegada_ubigeo, llegada_direccion, destinatario_tipo_documento, destinatario_numero_documento, destinatario_nombre,
      conductor, vehiculo_placa, estado, sunat_codigo, sunat_descripcion, entorno)
    values (r.id, v_est, v_usr, 'T001', v_t, v_ahora::date - r.n * 6, v_ahora::date - r.n * 6, '01', '02', 35 + r.n * 12, 'KGM', 3 + r.n,
      '150101', 'Av. Inventada 100, Lima', '150122', 'Jr. Ficticio ' || (300 + r.n) || ', Miraflores', '6', r.doc, r.nombre,
      jsonb_build_object('tipo_documento', '1', 'numero', '99123456', 'nombres', 'Tomás', 'apellidos', 'Ejemplo Ruta', 'licencia', 'Q99123456'),
      'DEM' || (100 + r.n), r.estado, '0', 'Documento de demostración, no enviado a SUNAT', 'beta');
    insert into public.guia_items (guia_id, producto_id, codigo, descripcion, unidad, cantidad)
      select r.id, p.id, p.codigo, p.nombre, p.unidad, 2 + (row_number() over ()) * 2
        from public.productos p where p.id = any(array[pg_temp.demo_id(2, 10 + r.n), pg_temp.demo_id(2, 32), pg_temp.demo_id(2, 37)]);
  end loop;

  update public.series set ultimo = greatest(ultimo, v_b) where tipo = '03' and serie = 'B001' and v_b > v_b0;
  update public.series set ultimo = greatest(ultimo, v_f) where tipo = '01' and serie = 'F001' and v_f > v_f0;
  update public.series set ultimo = greatest(ultimo, v_nv) where tipo = 'NV' and serie = 'NV01' and v_nv > v_nv0;
  update public.series set ultimo = greatest(ultimo, v_bc) where tipo = '07' and serie = 'BC01' and v_bc > v_bc0;
  update public.series set ultimo = greatest(ultimo, v_fc) where tipo = '07' and serie = 'FC01' and v_fc > v_fc0;
  update public.series set ultimo = greatest(ultimo, v_t) where tipo = '09' and serie = 'T001';
end;
$$;

select 'productos demo' as dato, count(*) as cantidad from public.productos where id::text like 'de000000-0000-4000-8000-0002%'
union all select 'clientes demo', count(*) from public.clientes where id::text like 'de000000-0000-4000-8000-0003%'
union all select 'comprobantes demo', count(*) from public.comprobantes where id::text like 'de000000-0000-4000-8000-0004%'
union all select 'turnos demo', count(*) from public.turnos_caja where id::text like 'de000000-0000-4000-8000-0005%'
union all select 'guias demo', count(*) from public.guias_remision where id::text like 'de000000-0000-4000-8000-0006%';

commit;
