-- =====================================================================
-- Avisos al maestro cuando un chico pregunta.
--
-- Antes había que acordarse de abrir el panel. Un chico que pregunta un
-- martes a la noche y recibe la respuesta el domingo ya se olvidó de
-- qué preguntó, y la próxima no pregunta.
--
-- Ahora, apenas entra una consulta, un disparador le pega a una función
-- de borde (avisar-consulta) que le manda la notificación al teléfono
-- del maestro. Va por Web Push: el navegador de él es el que avisa, no
-- hay servicio de terceros en el medio.
--
-- Los secretos (la clave privada VAPID y la palabra que autoriza al
-- disparador) NO están en este archivo: el repo es público. Viven en
-- vault, y se cargan una sola vez a mano. Si algún día hay que
-- rehacerlos, están las instrucciones en HANDOFF.md.
-- =====================================================================

create extension if not exists pg_net;

-- ---------------------------------------------------------------------
-- A qué teléfonos avisarle. Uno por navegador: el maestro puede tener
-- el celular y la compu, y le llega a los dos.
-- ---------------------------------------------------------------------
create table if not exists escuela.avisos_push (
  id             bigint generated always as identity primary key,
  grupo_id       uuid not null references escuela.grupos(id) on delete cascade,
  endpoint       text not null unique,
  p256dh         text not null,
  auth           text not null,
  creado_en      timestamptz not null default now(),
  ultimo_intento timestamptz,
  ultimo_estado  int,
  constraint avisos_push_endpoint_razonable check (length(endpoint) between 20 and 1000)
);

create index if not exists avisos_push_por_grupo on escuela.avisos_push (grupo_id);

alter table escuela.avisos_push enable row level security;

comment on table escuela.avisos_push is
  'Suscripciones Web Push del maestro. Las claves son del navegador de él: sirven para cifrarle el aviso y para nada más.';

-- =====================================================================
-- LADO DEL MAESTRO (desde el panel, con su token de sesión)
-- =====================================================================

create or replace function public.ed_maestro_push_alta(
  p_token uuid, p_endpoint text, p_p256dh text, p_auth text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_grupo uuid := escuela.grupo_por_token_maestro(p_token);
begin
  if v_grupo is null then
    return jsonb_build_object('ok', false, 'error', 'Tu sesion vencio. Volve a entrar.');
  end if;
  if coalesce(length(btrim(p_endpoint)), 0) < 20 or p_p256dh is null or p_auth is null then
    return jsonb_build_object('ok', false, 'error', 'Este navegador no dio una suscripcion valida.');
  end if;

  insert into escuela.avisos_push (grupo_id, endpoint, p256dh, auth)
  values (v_grupo, btrim(p_endpoint), p_p256dh, p_auth)
  on conflict (endpoint) do update
    set grupo_id = excluded.grupo_id,
        p256dh   = excluded.p256dh,
        auth     = excluded.auth,
        creado_en = now(),
        ultimo_estado = null;

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.ed_maestro_push_baja(p_token uuid, p_endpoint text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_grupo uuid := escuela.grupo_por_token_maestro(p_token);
begin
  if v_grupo is null then
    return jsonb_build_object('ok', false, 'error', 'Tu sesion vencio. Volve a entrar.');
  end if;

  delete from escuela.avisos_push
   where endpoint = btrim(p_endpoint) and grupo_id = v_grupo;

  return jsonb_build_object('ok', true);
end;
$$;

-- Para que el panel muestre si este teléfono ya está avisado o no.
create or replace function public.ed_maestro_push_estado(p_token uuid, p_endpoint text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_grupo uuid := escuela.grupo_por_token_maestro(p_token);
begin
  if v_grupo is null then
    return jsonb_build_object('ok', false, 'error', 'Tu sesion vencio. Volve a entrar.');
  end if;

  return jsonb_build_object('ok', true, 'activo', exists(
    select 1 from escuela.avisos_push
     where endpoint = btrim(p_endpoint) and grupo_id = v_grupo));
end;
$$;

-- =====================================================================
-- LADO DE LA FUNCIÓN DE BORDE (entra con la clave de servicio)
-- =====================================================================

-- Todo lo que hace falta para mandar un aviso, en una sola vuelta:
-- quién preguntó, qué preguntó, y a qué teléfonos avisarle.
create or replace function public.ed_push_aviso(p_consulta bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_c record;
begin
  select c.id, c.pregunta, c.estacion, c.leccion_slug, c.respondida_en,
         a.nombre, a.apellido, a.grupo_id, l.titulo as leccion
    into v_c
    from escuela.consultas c
    join escuela.alumnos a on a.id = c.alumno_id
    left join escuela.lecciones l on l.slug = c.leccion_slug
   where c.id = p_consulta;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'No existe esa consulta.');
  end if;

  return jsonb_build_object(
    'ok', true,
    'secreto', (select decrypted_secret from vault.decrypted_secrets where name = 'push_aviso_secreto'),
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

-- El navegador contesta 404/410 cuando el maestro desinstaló la app o
-- apagó los avisos desde el sistema. Esa suscripción ya no sirve más.
create or replace function public.ed_push_borrar(p_endpoint text)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  delete from escuela.avisos_push where endpoint = p_endpoint;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.ed_push_resultado(p_endpoint text, p_estado int)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  update escuela.avisos_push
     set ultimo_intento = now(), ultimo_estado = p_estado
   where endpoint = p_endpoint;
  return jsonb_build_object('ok', true);
end;
$$;

-- =====================================================================
-- El disparador
-- =====================================================================

create or replace function escuela.avisar_consulta_nueva()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_secreto text;
begin
  select decrypted_secret into v_secreto
    from vault.decrypted_secrets where name = 'push_aviso_secreto';

  -- Sin secreto cargado no avisamos, pero la pregunta se guarda igual:
  -- que no ande la notificación no puede romperle la app al chico.
  if v_secreto is null then
    return null;
  end if;

  -- La función de borde no pide JWT: se identifica con este secreto, que
  -- sale de vault y nunca sale del servidor.
  perform net.http_post(
    url := 'https://grswqigekcopfrozcxqj.supabase.co/functions/v1/avisar-consulta',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-aviso-secreto', v_secreto),
    body := jsonb_build_object('consulta', new.id),
    timeout_milliseconds := 5000);

  return null;
end;
$$;

drop trigger if exists consultas_avisan_al_maestro on escuela.consultas;
create trigger consultas_avisan_al_maestro
  after insert on escuela.consultas
  for each row execute function escuela.avisar_consulta_nueva();

-- ---------------------------------------------------------------------
-- Permisos
-- ---------------------------------------------------------------------
revoke all on function public.ed_maestro_push_alta(uuid, text, text, text) from public;
revoke all on function public.ed_maestro_push_baja(uuid, text)             from public;
revoke all on function public.ed_maestro_push_estado(uuid, text)           from public;
revoke all on function public.ed_push_aviso(bigint)                        from public;
revoke all on function public.ed_push_borrar(text)                         from public;
revoke all on function public.ed_push_resultado(text, int)                 from public;
revoke all on function escuela.avisar_consulta_nueva()                     from public;

grant execute on function public.ed_maestro_push_alta(uuid, text, text, text) to anon;
grant execute on function public.ed_maestro_push_baja(uuid, text)             to anon;
grant execute on function public.ed_maestro_push_estado(uuid, text)           to anon;

-- Estas tres son sólo para la función de borde: el chico y el maestro
-- nunca las llaman desde el navegador.
grant execute on function public.ed_push_aviso(bigint)      to service_role;
grant execute on function public.ed_push_borrar(text)       to service_role;
grant execute on function public.ed_push_resultado(text, int) to service_role;
