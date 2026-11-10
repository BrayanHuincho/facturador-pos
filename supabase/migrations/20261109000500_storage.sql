insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('documentos', 'documentos', false, null, null),
  ('imagenes', 'imagenes', true, 5242880, array['image/png', 'image/jpeg', 'image/webp']);

create policy imagenes_lectura_activos on storage.objects
  for select to authenticated
  using (bucket_id = 'imagenes' and (select public.rol_actual()) is not null);

create policy imagenes_insercion_admin on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'imagenes'
    and (storage.foldername(name))[1] in ('productos', 'logo')
    and (select public.es_admin())
  );

create policy imagenes_actualizacion_admin on storage.objects
  for update to authenticated
  using (
    bucket_id = 'imagenes'
    and (storage.foldername(name))[1] in ('productos', 'logo')
    and (select public.es_admin())
  )
  with check (
    bucket_id = 'imagenes'
    and (storage.foldername(name))[1] in ('productos', 'logo')
    and (select public.es_admin())
  );

create policy imagenes_borrado_admin on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'imagenes'
    and (storage.foldername(name))[1] in ('productos', 'logo')
    and (select public.es_admin())
  );
