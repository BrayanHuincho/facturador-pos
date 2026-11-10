alter table public.empresa
  add column modulos jsonb not null default '{"caja": false, "guias": true, "reportes": true, "nota_venta": true}'::jsonb,
  add column medios_pago text[] not null default array['efectivo', 'yape', 'plin', 'transferencia', 'tarjeta', 'deposito'],
  add column qr_yape_path text,
  add column qr_plin_path text;

alter table public.empresa
  add constraint empresa_medios_pago_validos
  check (medios_pago <@ array['efectivo', 'yape', 'plin', 'transferencia', 'tarjeta', 'deposito', 'otro'] and cardinality(medios_pago) > 0);
