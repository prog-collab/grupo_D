-- =====================================================================
-- Cerrarle a `anon` las funciones de los avisos.
--
-- 0011 hacía `revoke all ... from public` y después `grant ... to
-- service_role`, igual que el resto del esquema. No alcanza: Supabase
-- le da execute a `anon` y `authenticated` sobre las funciones nuevas
-- de public por privilegios por defecto, y eso no lo saca el revoke a
-- public.
--
-- El agujero era grande: `ed_push_aviso` devuelve la clave privada
-- VAPID y el secreto del disparador, y cualquiera con la clave
-- publicable —que está a la vista en index.html— podía pedírselos por
-- /rest/v1/rpc.
--
-- Se arregla por dos lados, para que no dependa de uno solo:
--   1. se les revoca execute a anon y authenticated, por nombre;
--   2. `ed_push_aviso` pasa a exigir el secreto como argumento y ya no
--      lo devuelve. Quien no lo sabe, no saca nada aunque llegue.
-- =====================================================================

drop function if exists public.ed_push_aviso(bigint);

create or replace function public.ed_push_aviso(p_consulta bigint, p_secreto text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_c record;
  v_secreto text;
begin
  select decrypted_secret into v_secreto
    from vault.decrypted_secrets where name = 'push_aviso_secreto';

  if v_secreto is null or p_secreto is null or p_secreto <> v_secreto then
    return jsonb_build_object('ok', false, 'error', 'No autorizado.');
  end if;

  select c.id, c.pregunta, c.estacion, c.leccion_slug,
         a.nombre, a.apellido, a.grupo_id, l.titulo as leccion
    into v_c
    from escuela.consultas c
    join escuela.alumnos a on a.id = c.alumno_id
    left join escuela.lecciones l on l.slug = c.leccion_slug
   where c.id = p_consulta;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'No existe esa consulta.');
  end if;

  -- El secreto no vuelve nunca: el que llama ya lo tenía que saber.
  return jsonb_build_object(
    'ok', true,
    'vapid',   (select decrypted_secret::jsonb from vault.decrypted_secrets where name = 'push_vapid_privada'),
    'contacto', 'mailto:jsgiusto@gmail.com',
    'titulo',  v_c.nombre || coalesce(' ' || v_c.apellido, '') || ' preguntó algo',
    'cuerpo',  left(v_c.pregunta, 180),
    'donde',   coalesce(v_c.leccion, 'la app') || coalesce(' · ' || v_c.estacion, ''),
    'consulta', v_c.id,
    'telefonos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'endpoint', p.endpoint, 'p256dh', p.p256dh, 'auth', p.auth))
        from escuela.avisos_push p
       where p.grupo_id = v_c.grupo_id), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.ed_push_aviso(bigint, text) from public, anon, authenticated;
revoke all on function public.ed_push_borrar(text)        from public, anon, authenticated;
revoke all on function public.ed_push_resultado(text, int) from public, anon, authenticated;

grant execute on function public.ed_push_aviso(bigint, text)  to service_role;
grant execute on function public.ed_push_borrar(text)         to service_role;
grant execute on function public.ed_push_resultado(text, int) to service_role;
