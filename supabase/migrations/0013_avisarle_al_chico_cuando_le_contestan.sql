-- =====================================================================
-- Avisarle al chico cuando el maestro le contesta.
--
-- La otra mitad del canal. El chico pregunta un martes a la noche y la
-- respuesta le queda esperando adentro de la actividad: si no vuelve a
-- entrar, no se entera nunca. Ahora le avisa el teléfono.
--
-- Con una diferencia importante respecto del aviso al maestro: **hay
-- horario**. Son chicos de 10 y 11 años y el teléfono duerme al lado de
-- la cama. Se avisa entre las 9 y las 22 (hora de Argentina); lo que
-- cae fuera de esa franja espera hasta las 9 de la mañana siguiente.
--
-- Eso obliga a una cola: el aviso ya no sale con el disparador y listo,
-- puede quedar guardado ocho horas. La cola es escuela.avisos_respuesta
-- y la despierta pg_cron cada 5 minutos.
-- =====================================================================

create extension if not exists pg_cron;

-- ---------------------------------------------------------------------
-- A qué teléfonos avisarle. Es por (chico, aparato): en un teléfono
-- pueden entrar dos hermanos, y cada uno tiene que recibir lo suyo.
-- ---------------------------------------------------------------------
create table if not exists escuela.avisos_push_alumno (
  id             bigint generated always as identity primary key,
  alumno_id      uuid not null references escuela.alumnos(id) on delete cascade,
  endpoint       text not null,
  p256dh         text not null,
  auth           text not null,
  creado_en      timestamptz not null default now(),
  ultimo_intento timestamptz,
  ultimo_estado  int,
  unique (alumno_id, endpoint),
  constraint avisos_push_alumno_endpoint_razonable check (length(endpoint) between 20 and 1000)
);

alter table escuela.avisos_push_alumno enable row level security;

comment on table escuela.avisos_push_alumno is
  'Suscripciones Web Push de los chicos, una por chico y aparato. Solo se usan para avisarle que le contestaron.';

-- ---------------------------------------------------------------------
-- La cola. Una fila por respuesta a avisar, con la hora a partir de la
-- cual se puede mandar.
-- ---------------------------------------------------------------------
create table if not exists escuela.avisos_respuesta (
  id           bigint generated always as identity primary key,
  consulta_id  bigint not null unique references escuela.consultas(id) on delete cascade,
  alumno_id    uuid not null references escuela.alumnos(id) on delete cascade,
  enviar_desde timestamptz not null,
  reclamado_en timestamptz,
  enviado_en   timestamptz,
  intentos     int not null default 0,
  creado_en    timestamptz not null default now()
);

create index if not exists avisos_respuesta_pendientes
  on escuela.avisos_respuesta (enviado_en, enviar_desde);

alter table escuela.avisos_respuesta enable row level security;

-- ---------------------------------------------------------------------
-- El horario. Entre las 9 y las 22 se manda ya; fuera de eso, a las 9
-- de la mañana siguiente. La hora es la de Argentina, no la del
-- servidor, que vive en UTC.
-- ---------------------------------------------------------------------
create or replace function escuela.hora_de_avisar(p_ahora timestamptz)
returns timestamptz language sql stable set search_path = '' as $$
  with acá as (select p_ahora at time zone 'America/Argentina/Buenos_Aires' as t)
  select case
    when extract(hour from t) between 9 and 21 then p_ahora
    when extract(hour from t) < 9
      then (date_trunc('day', t) + interval '9 hours') at time zone 'America/Argentina/Buenos_Aires'
    else (date_trunc('day', t) + interval '1 day 9 hours') at time zone 'America/Argentina/Buenos_Aires'
  end
  from acá;
$$;

comment on function escuela.hora_de_avisar(timestamptz) is
  'Cuándo se le puede avisar a un chico: ya, si son entre las 9 y las 22 en Argentina; si no, a las 9 de la mañana siguiente.';

-- ---------------------------------------------------------------------
-- El disparador: cuando una consulta pasa a respondida, va a la cola.
-- Si la corrige más tarde no vuelve a avisar: ya le avisamos una vez y
-- el chico tiene la respuesta abierta en la actividad.
-- ---------------------------------------------------------------------
create or replace function escuela.encolar_aviso_respuesta()
returns trigger language plpgsql security definer set search_path = '' as $$
declare
  v_cuando timestamptz := escuela.hora_de_avisar(now());
begin
  insert into escuela.avisos_respuesta (consulta_id, alumno_id, enviar_desde)
  values (new.id, new.alumno_id, v_cuando)
  on conflict (consulta_id) do nothing;

  -- Si es hora, que salga ya; si no, lo va a levantar el cron a las 9.
  if v_cuando <= now() then
    perform escuela.despachar_avisos_respuesta();
  end if;

  return null;
end;
$$;

-- Le pega a la función de borde para que vacíe la cola. La usan el
-- disparador (aviso inmediato) y el cron (los que quedaron esperando).
create or replace function escuela.despachar_avisos_respuesta()
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_secreto text;
begin
  select decrypted_secret into v_secreto
    from vault.decrypted_secrets where name = 'push_aviso_secreto';
  if v_secreto is null then
    return;
  end if;

  perform net.http_post(
    url := 'https://grswqigekcopfrozcxqj.supabase.co/functions/v1/avisar-respuesta',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-aviso-secreto', v_secreto),
    body := '{}'::jsonb,
    timeout_milliseconds := 5000);
end;
$$;

drop trigger if exists respuestas_avisan_al_chico on escuela.consultas;
create trigger respuestas_avisan_al_chico
  after update on escuela.consultas
  for each row
  when (old.respondida_en is null and new.respondida_en is not null)
  execute function escuela.encolar_aviso_respuesta();

-- =====================================================================
-- LADO DEL CHICO (desde la app, con su token de siempre)
-- =====================================================================

create or replace function public.ed_alumno_push_alta(
  p_token uuid, p_endpoint text, p_p256dh text, p_auth text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_alumno uuid := escuela.alumno_por_token(p_token);
begin
  if v_alumno is null then
    return jsonb_build_object('ok', false, 'error', 'Sesion no valida.');
  end if;
  if coalesce(length(btrim(p_endpoint)), 0) < 20 or p_p256dh is null or p_auth is null then
    return jsonb_build_object('ok', false, 'error', 'Este navegador no dio una suscripcion valida.');
  end if;

  insert into escuela.avisos_push_alumno (alumno_id, endpoint, p256dh, auth)
  values (v_alumno, btrim(p_endpoint), p_p256dh, p_auth)
  on conflict (alumno_id, endpoint) do update
    set p256dh = excluded.p256dh,
        auth   = excluded.auth,
        creado_en = now(),
        ultimo_estado = null;

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.ed_alumno_push_baja(p_token uuid, p_endpoint text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_alumno uuid := escuela.alumno_por_token(p_token);
begin
  if v_alumno is null then
    return jsonb_build_object('ok', false, 'error', 'Sesion no valida.');
  end if;

  delete from escuela.avisos_push_alumno
   where alumno_id = v_alumno and endpoint = btrim(p_endpoint);

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.ed_alumno_push_estado(p_token uuid, p_endpoint text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_alumno uuid := escuela.alumno_por_token(p_token);
begin
  if v_alumno is null then
    return jsonb_build_object('ok', false, 'error', 'Sesion no valida.');
  end if;

  return jsonb_build_object('ok', true, 'activo', exists(
    select 1 from escuela.avisos_push_alumno
     where alumno_id = v_alumno and endpoint = btrim(p_endpoint)));
end;
$$;

-- =====================================================================
-- LADO DE LA FUNCIÓN DE BORDE
-- =====================================================================

-- Saca de la cola lo que ya se puede mandar y lo marca como reclamado,
-- para que dos corridas al mismo tiempo no avisen dos veces. Si algo
-- falla, en 5 minutos vuelve a estar disponible; después de 5 intentos
-- se deja de insistir.
create or replace function public.ed_push_respuestas(p_secreto text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_secreto text;
  v_avisos jsonb;
begin
  select decrypted_secret into v_secreto
    from vault.decrypted_secrets where name = 'push_aviso_secreto';

  if v_secreto is null or p_secreto is null or p_secreto <> v_secreto then
    return jsonb_build_object('ok', false, 'error', 'No autorizado.');
  end if;

  with reclamados as (
    update escuela.avisos_respuesta q
       set reclamado_en = now(), intentos = q.intentos + 1
     where q.id in (
       select id from escuela.avisos_respuesta
        where enviado_en is null
          and enviar_desde <= now()
          and intentos < 5
          and (reclamado_en is null or reclamado_en < now() - interval '5 minutes')
        order by enviar_desde
        limit 50
        for update skip locked)
    returning q.id, q.consulta_id, q.alumno_id)
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', p.id,
           'titulo', 'Tu maestro te contestó, ' || a.nombre,
           'cuerpo', left(c.respuesta, 180),
           'donde', coalesce(l.titulo, 'la app'),
           'url', 'index.html?leccion=' || c.leccion_slug || '#est-' || c.estacion,
           'tag', 'respuesta-' || p.consulta_id,
           'telefonos', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'endpoint', t.endpoint, 'p256dh', t.p256dh, 'auth', t.auth))
               from escuela.avisos_push_alumno t
              where t.alumno_id = p.alumno_id), '[]'::jsonb))), '[]'::jsonb)
    into v_avisos
    from reclamados p
    join escuela.consultas c on c.id = p.consulta_id
    join escuela.alumnos a on a.id = p.alumno_id
    left join escuela.lecciones l on l.slug = c.leccion_slug;

  return jsonb_build_object(
    'ok', true,
    'vapid', (select decrypted_secret::jsonb from vault.decrypted_secrets where name = 'push_vapid_privada'),
    'contacto', 'mailto:jsgiusto@gmail.com',
    'avisos', v_avisos
  );
end;
$$;

create or replace function public.ed_push_respuesta_lista(p_secreto text, p_id bigint)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_secreto text;
begin
  select decrypted_secret into v_secreto
    from vault.decrypted_secrets where name = 'push_aviso_secreto';

  if v_secreto is null or p_secreto is null or p_secreto <> v_secreto then
    return jsonb_build_object('ok', false, 'error', 'No autorizado.');
  end if;

  update escuela.avisos_respuesta set enviado_en = now() where id = p_id;
  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.ed_push_alumno_borrar(p_secreto text, p_endpoint text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_secreto text;
begin
  select decrypted_secret into v_secreto
    from vault.decrypted_secrets where name = 'push_aviso_secreto';

  if v_secreto is null or p_secreto is null or p_secreto <> v_secreto then
    return jsonb_build_object('ok', false, 'error', 'No autorizado.');
  end if;

  delete from escuela.avisos_push_alumno where endpoint = p_endpoint;
  return jsonb_build_object('ok', true);
end;
$$;

-- ---------------------------------------------------------------------
-- El reloj: cada 5 minutos mira si hay algo para mandar. Es el que
-- despierta a los avisos que quedaron esperando a las 9.
-- ---------------------------------------------------------------------
select cron.unschedule('avisos-respuesta') where exists (
  select 1 from cron.job where jobname = 'avisos-respuesta');

select cron.schedule('avisos-respuesta', '*/5 * * * *',
  $job$ select escuela.despachar_avisos_respuesta(); $job$);

-- ---------------------------------------------------------------------
-- Permisos.
--
-- Ojo con lo que aprendimos en 0012: el revoke a public NO alcanza,
-- Supabase le da execute a anon y authenticated por privilegios por
-- defecto. Hay que revocárselo por nombre.
-- ---------------------------------------------------------------------
revoke all on function public.ed_alumno_push_alta(uuid, text, text, text) from public;
revoke all on function public.ed_alumno_push_baja(uuid, text)             from public;
revoke all on function public.ed_alumno_push_estado(uuid, text)           from public;

revoke all on function public.ed_push_respuestas(text)              from public, anon, authenticated;
revoke all on function public.ed_push_respuesta_lista(text, bigint) from public, anon, authenticated;
revoke all on function public.ed_push_alumno_borrar(text, text)     from public, anon, authenticated;
revoke all on function escuela.hora_de_avisar(timestamptz)          from public, anon, authenticated;
revoke all on function escuela.despachar_avisos_respuesta()         from public, anon, authenticated;
revoke all on function escuela.encolar_aviso_respuesta()            from public, anon, authenticated;

grant execute on function public.ed_alumno_push_alta(uuid, text, text, text) to anon;
grant execute on function public.ed_alumno_push_baja(uuid, text)             to anon;
grant execute on function public.ed_alumno_push_estado(uuid, text)           to anon;

grant execute on function public.ed_push_respuestas(text)              to service_role;
grant execute on function public.ed_push_respuesta_lista(text, bigint) to service_role;
grant execute on function public.ed_push_alumno_borrar(text, text)     to service_role;
