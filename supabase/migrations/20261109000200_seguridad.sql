create function public.rol_actual()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select rol
  from public.perfiles
  where id = (select auth.uid())
    and activo
$$;

create function public.es_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(public.rol_actual() = 'admin', false)
$$;

create function public.obtener_estado_sunat()
returns table (
  entorno text,
  usuario_sol text,
  tiene_clave_sol boolean,
  tiene_certificado boolean,
  certificado_vence_en timestamptz,
  certificado_titular text,
  tiene_gre boolean,
  envio_boletas text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador puede consultar la configuracion SUNAT'
      using errcode = '42501';
  end if;

  return query
  select
    c.entorno,
    c.usuario_sol,
    c.clave_sol_cifrada is not null,
    c.certificado_cifrado is not null,
    c.certificado_vence_en,
    c.certificado_titular,
    c.gre_client_id is not null and c.gre_client_secret_cifrado is not null,
    c.envio_boletas
  from public.configuracion_sunat c
  where c.id = 1;
end;
$$;

create view public.v_configuracion_sunat as
select * from public.obtener_estado_sunat();

revoke all on all tables in schema public from anon, authenticated;
revoke all on all functions in schema public from public, anon, authenticated;

grant execute on function public.rol_actual() to authenticated, service_role;
grant execute on function public.es_admin() to authenticated, service_role;
grant execute on function public.obtener_estado_sunat() to authenticated, service_role;

grant select on public.v_configuracion_sunat to authenticated;

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
    execute format('alter table public.%I enable row level security', tabla);
  end loop;

  foreach tabla in array array[
    'empresa', 'establecimientos', 'perfiles', 'series', 'categorias', 'productos',
    'stock', 'movimientos_stock', 'clientes', 'turnos_caja', 'movimientos_caja',
    'resumenes_diarios', 'comprobantes', 'comprobante_items', 'pagos',
    'comunicaciones_baja', 'guias_remision', 'guia_items', 'auditoria'
  ]
  loop
    execute format('grant select on public.%I to authenticated', tabla);
  end loop;

  foreach tabla in array array['empresa', 'establecimientos', 'series', 'categorias', 'productos', 'stock', 'clientes']
  loop
    execute format(
      'create policy lectura_activos on public.%I for select to authenticated using ((select public.rol_actual()) is not null)',
      tabla
    );
  end loop;

  foreach tabla in array array['categorias', 'productos']
  loop
    execute format('grant insert, update, delete on public.%I to authenticated', tabla);
    execute format(
      'create policy insercion_admin on public.%I for insert to authenticated with check ((select public.es_admin()))',
      tabla
    );
    execute format(
      'create policy actualizacion_admin on public.%I for update to authenticated using ((select public.es_admin())) with check ((select public.es_admin()))',
      tabla
    );
    execute format(
      'create policy borrado_admin on public.%I for delete to authenticated using ((select public.es_admin()))',
      tabla
    );
  end loop;

  foreach tabla in array array['comprobantes', 'turnos_caja', 'guias_remision', 'movimientos_stock']
  loop
    execute format(
      'create policy lectura_propia_o_supervision on public.%I for select to authenticated using ((select public.rol_actual()) in (''admin'', ''contador'') or ((select public.rol_actual()) = ''cajero'' and usuario_id = (select auth.uid())))',
      tabla
    );
  end loop;

  foreach tabla in array array['resumenes_diarios', 'comunicaciones_baja']
  loop
    execute format(
      'create policy lectura_supervision on public.%I for select to authenticated using ((select public.rol_actual()) in (''admin'', ''contador''))',
      tabla
    );
  end loop;
end;
$$;

grant insert, update, delete on public.clientes to authenticated;

create policy insercion_admin_cajero on public.clientes
  for insert to authenticated
  with check ((select public.rol_actual()) in ('admin', 'cajero'));

create policy actualizacion_admin_cajero on public.clientes
  for update to authenticated
  using ((select public.rol_actual()) in ('admin', 'cajero'))
  with check ((select public.rol_actual()) in ('admin', 'cajero'));

create policy borrado_admin on public.clientes
  for delete to authenticated
  using ((select public.es_admin()));

create policy lectura_propia_o_admin on public.perfiles
  for select to authenticated
  using ((select public.rol_actual()) is not null and (id = (select auth.uid()) or (select public.es_admin())));

create policy lectura_propia_o_supervision on public.movimientos_caja
  for select to authenticated
  using (
    (select public.rol_actual()) in ('admin', 'contador')
    or (
      (select public.rol_actual()) = 'cajero'
      and exists (
        select 1 from public.turnos_caja t
        where t.id = turno_id and t.usuario_id = (select auth.uid())
      )
    )
  );

create policy lectura_segun_comprobante on public.comprobante_items
  for select to authenticated
  using (exists (select 1 from public.comprobantes c where c.id = comprobante_id));

create policy lectura_segun_comprobante on public.pagos
  for select to authenticated
  using (exists (select 1 from public.comprobantes c where c.id = comprobante_id));

create policy lectura_segun_guia on public.guia_items
  for select to authenticated
  using (exists (select 1 from public.guias_remision g where g.id = guia_id));

create policy lectura_admin on public.auditoria
  for select to authenticated
  using ((select public.es_admin()));
