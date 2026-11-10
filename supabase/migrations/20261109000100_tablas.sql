create function public.fijar_actualizado_en()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.actualizado_en = now();
  return new;
end;
$$;

create table public.empresa (
  id int primary key default 1 check (id = 1),
  ruc text,
  razon_social text,
  nombre_comercial text,
  ubigeo text,
  departamento text,
  provincia text,
  distrito text,
  direccion text,
  telefono text,
  correo text,
  logo_path text,
  igv_porcentaje numeric(5,2) not null default 18,
  precios_incluyen_igv boolean not null default true,
  configurada boolean not null default false,
  plantilla_pdf text not null default 'clasica' check (plantilla_pdf in ('clasica', 'moderna', 'minimalista', 'ejecutiva', 'compacta')),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.configuracion_sunat (
  id int primary key default 1 check (id = 1),
  entorno text not null default 'beta' check (entorno in ('beta', 'produccion')),
  usuario_sol text,
  clave_sol_cifrada text,
  certificado_cifrado text,
  certificado_vence_en timestamptz,
  certificado_titular text,
  gre_client_id text,
  gre_client_secret_cifrado text,
  envio_boletas text not null default 'individual' check (envio_boletas in ('individual', 'resumen_diario')),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.establecimientos (
  id uuid primary key default gen_random_uuid(),
  codigo text not null default '0000',
  nombre text not null,
  direccion text,
  ubigeo text,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.perfiles (
  id uuid primary key references auth.users (id) on delete cascade,
  nombre text not null,
  rol text not null default 'cajero' check (rol in ('admin', 'cajero', 'contador')),
  establecimiento_id uuid references public.establecimientos (id) on delete set null,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.series (
  id uuid primary key default gen_random_uuid(),
  establecimiento_id uuid not null references public.establecimientos (id),
  tipo text not null check (tipo in ('01', '03', '07', '08', '09', 'NV')),
  serie text not null check (char_length(serie) = 4),
  ultimo int not null default 0,
  activa boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (tipo, serie)
);

create table public.categorias (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  orden int not null default 0,
  activa boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.productos (
  id uuid primary key default gen_random_uuid(),
  codigo text,
  codigo_barras text,
  nombre text not null,
  descripcion text,
  categoria_id uuid references public.categorias (id) on delete set null,
  unidad text not null default 'NIU',
  precio numeric(18,6) not null default 0,
  costo numeric(18,6),
  afectacion text not null default '10' check (afectacion in ('10', '20', '30')),
  aplica_icbper boolean not null default false,
  controla_stock boolean not null default false,
  stock_minimo numeric(18,4),
  imagen_path text,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.stock (
  id uuid primary key default gen_random_uuid(),
  producto_id uuid not null references public.productos (id) on delete cascade,
  establecimiento_id uuid not null references public.establecimientos (id),
  cantidad numeric(18,4) not null default 0,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (producto_id, establecimiento_id)
);

create table public.movimientos_stock (
  id uuid primary key default gen_random_uuid(),
  producto_id uuid not null references public.productos (id),
  establecimiento_id uuid not null references public.establecimientos (id),
  tipo text not null check (tipo in ('venta', 'anulacion', 'ajuste', 'compra')),
  cantidad numeric(18,4) not null,
  referencia_id uuid,
  usuario_id uuid references public.perfiles (id),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.clientes (
  id uuid primary key default gen_random_uuid(),
  tipo_documento text not null check (tipo_documento in ('0', '1', '4', '6', '7')),
  numero_documento text not null,
  nombre text not null,
  direccion text,
  ubigeo text,
  telefono text,
  correo text,
  activo boolean not null default true,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (tipo_documento, numero_documento)
);

create table public.turnos_caja (
  id uuid primary key default gen_random_uuid(),
  establecimiento_id uuid not null references public.establecimientos (id),
  usuario_id uuid not null references public.perfiles (id),
  estado text not null default 'abierto' check (estado in ('abierto', 'cerrado')),
  abierto_en timestamptz not null default now(),
  cerrado_en timestamptz,
  monto_apertura numeric(18,2) not null default 0,
  monto_esperado numeric(18,2),
  monto_contado numeric(18,2),
  diferencia numeric(18,2),
  observacion text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create unique index turnos_caja_un_abierto_por_usuario
  on public.turnos_caja (usuario_id)
  where estado = 'abierto';

create table public.movimientos_caja (
  id uuid primary key default gen_random_uuid(),
  turno_id uuid not null references public.turnos_caja (id),
  tipo text not null check (tipo in ('ingreso', 'egreso')),
  monto numeric(18,2) not null,
  concepto text not null,
  usuario_id uuid references public.perfiles (id),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.resumenes_diarios (
  id uuid primary key default gen_random_uuid(),
  fecha_referencia date not null,
  fecha_generacion date,
  correlativo int,
  identificador text,
  estado text not null default 'pendiente',
  ticket text,
  sunat_codigo text,
  sunat_descripcion text,
  xml_path text,
  cdr_path text,
  items jsonb not null default '[]'::jsonb,
  entorno text check (entorno in ('beta', 'produccion')),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.comprobantes (
  id uuid primary key default gen_random_uuid(),
  establecimiento_id uuid not null references public.establecimientos (id),
  turno_id uuid references public.turnos_caja (id),
  usuario_id uuid not null references public.perfiles (id),
  tipo text not null check (tipo in ('01', '03', '07', '08', 'NV')),
  serie text not null check (char_length(serie) = 4),
  correlativo int not null,
  fecha_emision date not null default current_date,
  hora_emision time not null default current_time,
  moneda text not null default 'PEN',
  tipo_cambio numeric(18,6),
  forma_pago text not null default 'contado' check (forma_pago in ('contado', 'credito')),
  cuotas jsonb,
  cliente_id uuid references public.clientes (id),
  cliente_tipo_documento text,
  cliente_numero_documento text,
  cliente_nombre text,
  cliente_direccion text,
  op_gravadas numeric(18,2) not null default 0,
  op_exoneradas numeric(18,2) not null default 0,
  op_inafectas numeric(18,2) not null default 0,
  op_gratuitas numeric(18,2) not null default 0,
  descuento_total numeric(18,2) not null default 0,
  igv numeric(18,2) not null default 0,
  icbper numeric(18,2) not null default 0,
  total numeric(18,2) not null default 0,
  recibido numeric(18,2),
  vuelto numeric(18,2),
  detraccion jsonb,
  leyendas jsonb,
  afectado_id uuid references public.comprobantes (id),
  afectado_tipo text,
  afectado_serie text,
  afectado_correlativo int,
  motivo_codigo text,
  motivo_descripcion text,
  estado text not null default 'pendiente' check (estado in ('pendiente', 'enviando', 'aceptado', 'observado', 'rechazado', 'error', 'por_resumen', 'por_anular', 'anulado', 'no_aplica')),
  sunat_codigo text,
  sunat_descripcion text,
  sunat_notas jsonb,
  hash text,
  qr text,
  xml_path text,
  cdr_path text,
  pdf_path text,
  entorno text check (entorno in ('beta', 'produccion')),
  clave_idempotencia text unique,
  intentos int not null default 0,
  resumen_id uuid references public.resumenes_diarios (id),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (tipo, serie, correlativo)
);

create table public.comprobante_items (
  id uuid primary key default gen_random_uuid(),
  comprobante_id uuid not null references public.comprobantes (id),
  producto_id uuid references public.productos (id),
  orden int not null default 0,
  codigo text,
  descripcion text not null,
  unidad text not null default 'NIU',
  cantidad numeric(18,4) not null,
  precio_unitario numeric(18,6) not null,
  valor_unitario numeric(18,6) not null,
  descuento numeric(18,2) not null default 0,
  afectacion text not null,
  base numeric(18,2) not null default 0,
  igv numeric(18,2) not null default 0,
  icbper numeric(18,2) not null default 0,
  total numeric(18,2) not null default 0,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.pagos (
  id uuid primary key default gen_random_uuid(),
  comprobante_id uuid not null references public.comprobantes (id),
  medio text not null check (medio in ('efectivo', 'yape', 'plin', 'transferencia', 'tarjeta', 'deposito', 'otro')),
  monto numeric(18,2) not null,
  referencia text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.comunicaciones_baja (
  id uuid primary key default gen_random_uuid(),
  fecha_referencia date not null,
  fecha_generacion date,
  correlativo int,
  identificador text,
  estado text not null default 'pendiente',
  ticket text,
  sunat_codigo text,
  sunat_descripcion text,
  xml_path text,
  cdr_path text,
  items jsonb not null default '[]'::jsonb,
  entorno text check (entorno in ('beta', 'produccion')),
  comprobante_id uuid references public.comprobantes (id),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.guias_remision (
  id uuid primary key default gen_random_uuid(),
  establecimiento_id uuid not null references public.establecimientos (id),
  usuario_id uuid not null references public.perfiles (id),
  serie text not null check (char_length(serie) = 4),
  correlativo int not null,
  fecha_emision date not null default current_date,
  fecha_traslado date,
  motivo_codigo text,
  modalidad text check (modalidad in ('01', '02')),
  peso_total numeric(18,4),
  unidad_peso text,
  bultos int,
  partida_ubigeo text,
  partida_direccion text,
  llegada_ubigeo text,
  llegada_direccion text,
  destinatario_tipo_documento text,
  destinatario_numero_documento text,
  destinatario_nombre text,
  transportista jsonb,
  conductor jsonb,
  vehiculo_placa text,
  comprobante_id uuid references public.comprobantes (id),
  estado text not null default 'pendiente',
  ticket text,
  sunat_codigo text,
  sunat_descripcion text,
  xml_path text,
  cdr_path text,
  pdf_path text,
  qr text,
  entorno text check (entorno in ('beta', 'produccion')),
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  unique (serie, correlativo)
);

create table public.guia_items (
  id uuid primary key default gen_random_uuid(),
  guia_id uuid not null references public.guias_remision (id),
  producto_id uuid references public.productos (id),
  codigo text,
  descripcion text not null,
  unidad text not null default 'NIU',
  cantidad numeric(18,4) not null,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.trabajos (
  id uuid primary key default gen_random_uuid(),
  tipo text not null check (tipo in ('enviar_comprobante', 'consultar_ticket', 'enviar_resumen', 'enviar_baja', 'enviar_guia', 'consultar_guia', 'generar_resumen_diario')),
  payload jsonb not null default '{}'::jsonb,
  estado text not null default 'pendiente' check (estado in ('pendiente', 'procesando', 'hecho', 'fallido')),
  intentos int not null default 0,
  max_intentos int not null default 7,
  ejecutar_en timestamptz not null default now(),
  bloqueado_en timestamptz,
  ultimo_error text,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create table public.auditoria (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid references public.perfiles (id) on delete set null,
  accion text not null,
  entidad text not null,
  entidad_id text,
  detalle jsonb,
  creado_en timestamptz not null default now(),
  actualizado_en timestamptz not null default now()
);

create index perfiles_establecimiento_idx on public.perfiles (establecimiento_id);
create index series_establecimiento_idx on public.series (establecimiento_id);
create index productos_categoria_idx on public.productos (categoria_id);
create index productos_codigo_idx on public.productos (codigo);
create index productos_codigo_barras_idx on public.productos (codigo_barras);
create index stock_establecimiento_idx on public.stock (establecimiento_id);
create index movimientos_stock_producto_idx on public.movimientos_stock (producto_id, creado_en desc);
create index movimientos_stock_establecimiento_idx on public.movimientos_stock (establecimiento_id);
create index movimientos_stock_usuario_idx on public.movimientos_stock (usuario_id);
create index turnos_caja_usuario_idx on public.turnos_caja (usuario_id, abierto_en desc);
create index turnos_caja_establecimiento_idx on public.turnos_caja (establecimiento_id);
create index movimientos_caja_turno_idx on public.movimientos_caja (turno_id);
create index movimientos_caja_usuario_idx on public.movimientos_caja (usuario_id);
create index comprobantes_usuario_fecha_idx on public.comprobantes (usuario_id, fecha_emision desc);
create index comprobantes_fecha_idx on public.comprobantes (fecha_emision desc);
create index comprobantes_estado_idx on public.comprobantes (estado);
create index comprobantes_establecimiento_idx on public.comprobantes (establecimiento_id);
create index comprobantes_turno_idx on public.comprobantes (turno_id);
create index comprobantes_cliente_idx on public.comprobantes (cliente_id);
create index comprobantes_afectado_idx on public.comprobantes (afectado_id);
create index comprobantes_resumen_idx on public.comprobantes (resumen_id);
create index comprobante_items_comprobante_idx on public.comprobante_items (comprobante_id);
create index comprobante_items_producto_idx on public.comprobante_items (producto_id);
create index pagos_comprobante_idx on public.pagos (comprobante_id);
create index resumenes_diarios_fecha_idx on public.resumenes_diarios (fecha_referencia desc);
create index comunicaciones_baja_fecha_idx on public.comunicaciones_baja (fecha_referencia desc);
create index comunicaciones_baja_comprobante_idx on public.comunicaciones_baja (comprobante_id);
create index guias_remision_usuario_fecha_idx on public.guias_remision (usuario_id, fecha_emision desc);
create index guias_remision_establecimiento_idx on public.guias_remision (establecimiento_id);
create index guias_remision_comprobante_idx on public.guias_remision (comprobante_id);
create index guia_items_guia_idx on public.guia_items (guia_id);
create index guia_items_producto_idx on public.guia_items (producto_id);
create index trabajos_pendientes_idx on public.trabajos (ejecutar_en) where estado = 'pendiente';
create index trabajos_procesando_idx on public.trabajos (bloqueado_en) where estado = 'procesando';
create index auditoria_entidad_idx on public.auditoria (entidad, entidad_id);
create index auditoria_usuario_idx on public.auditoria (usuario_id);
create index auditoria_creado_idx on public.auditoria (creado_en desc);

do $$
declare
  tabla text;
begin
  foreach tabla in array array[
    'empresa', 'configuracion_sunat', 'establecimientos', 'perfiles', 'series',
    'categorias', 'productos', 'stock', 'movimientos_stock', 'clientes',
    'turnos_caja', 'movimientos_caja', 'resumenes_diarios', 'comprobantes',
    'comprobante_items', 'pagos', 'comunicaciones_baja', 'guias_remision',
    'guia_items', 'trabajos', 'auditoria'
  ]
  loop
    execute format(
      'create trigger fijar_actualizado_en before update on public.%I for each row execute function public.fijar_actualizado_en()',
      tabla
    );
  end loop;
end;
$$;

insert into public.empresa (id) values (1);
insert into public.configuracion_sunat (id) values (1);
