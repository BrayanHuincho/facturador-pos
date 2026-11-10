create function public.crear_perfil_de_usuario_nuevo()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  es_primer_usuario boolean;
  rol_provisionado text := new.raw_app_meta_data ->> 'rol';
  rol_valido boolean := rol_provisionado in ('admin', 'cajero', 'contador');
begin
  perform pg_advisory_xact_lock(hashtext('public.perfiles.primer_usuario'));

  select not exists (select 1 from public.perfiles) into es_primer_usuario;

  insert into public.perfiles (id, nombre, rol, activo)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'nombre'), ''), nullif(split_part(coalesce(new.email, ''), '@', 1), ''), 'Usuario'),
    case
      when es_primer_usuario then 'admin'
      when coalesce(rol_valido, false) then rol_provisionado
      else 'cajero'
    end,
    es_primer_usuario or coalesce(rol_valido, false)
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

revoke all on function public.crear_perfil_de_usuario_nuevo() from public, anon, authenticated;

create trigger crear_perfil_al_registrar_usuario
  after insert on auth.users
  for each row execute function public.crear_perfil_de_usuario_nuevo();
