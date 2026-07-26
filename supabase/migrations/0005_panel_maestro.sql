-- =====================================================================
-- Panel del maestro + consultas de los chicos.
--
-- Las consultas son chico -> maestro y nada más. No hay chat entre
-- alumnos: nadie ve lo que preguntó otro. Un canal abierto entre
-- menores necesitaría moderación en vivo, y no la hay.
--
-- El maestro no manda su clave en cada llamada: entra una vez y recibe
-- un token con vencimiento. Así la clave viaja una sola vez por sesión.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Consultas
-- ---------------------------------------------------------------------
create table if not exists escuela.consultas (
  id                bigint generated always as identity primary key,
  alumno_id         uuid not null references escuela.alumnos(id) on delete cascade,
  leccion_slug      text references escuela.lecciones(slug) on delete set null,
  estacion          text,
  pregunta          text not null,
  respuesta         text,
  respondida_en     timestamptz,
  vista_por_alumno  boolean not null default false,
  creado_en         timestamptz not null default now(),
  constraint consultas_pregunta_razonable check (length(btrim(pregunta)) between 5 and 600),
  constraint consultas_respuesta_razonable check (respuesta is null or length(respuesta) <= 1500)
);

create index if not exists consultas_pendientes on escuela.consultas (respondida_en, creado_en);
create index if not exists consultas_por_alumno on escuela.consultas (alumno_id, leccion_slug);

alter table escuela.consultas enable row level security;

-- ---------------------------------------------------------------------
-- Sesiones del maestro
-- ---------------------------------------------------------------------
create table if not exists escuela.sesiones_maestro (
  token     uuid primary key default gen_random_uuid(),
  grupo_id  uuid not null references escuela.grupos(id) on delete cascade,
  creado_en timestamptz not null default now(),
  expira_en timestamptz not null default now() + interval '8 hours'
);

alter table escuela.sesiones_maestro enable row level security;

revoke all on all tables in schema escuela from anon, authenticated;

-- ---------------------------------------------------------------------
-- Helper: token de maestro -> grupo
-- ---------------------------------------------------------------------
create or replace function escuela.grupo_por_token_maestro(p_token uuid)
returns uuid language sql security definer set search_path = '' stable as $$
  select grupo_id from escuela.sesiones_maestro
   where token = p_token and expira_en > now();
$$;

-- =====================================================================
-- LADO DE LOS CHICOS
-- =====================================================================

create or replace function public.ed_consulta_crear(
  p_token uuid, p_leccion text, p_estacion text, p_pregunta text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_alumno uuid := escuela.alumno_por_token(p_token);
  v_abiertas int;
begin
  if v_alumno is null then
    return jsonb_build_object('ok', false, 'error', 'Sesion no valida.');
  end if;

  if length(btrim(p_pregunta)) < 5 then
    return jsonb_build_object('ok', false, 'error', 'Escribi un poco mas para que tu maestro entienda la duda.');
  end if;

  -- Freno anti-spam: no mas de 10 preguntas sin responder a la vez.
  select count(*) into v_abiertas
    from escuela.consultas
   where alumno_id = v_alumno and respondida_en is null;

  if v_abiertas >= 10 then
    return jsonb_build_object('ok', false,
      'error', 'Ya tenes varias preguntas esperando respuesta. Espera a que tu maestro conteste esas.');
  end if;

  insert into escuela.consultas (alumno_id, leccion_slug, estacion, pregunta)
  values (v_alumno, p_leccion, p_estacion, left(btrim(p_pregunta), 600));

  return jsonb_build_object('ok', true);
end;
$$;

create or replace function public.ed_mis_consultas(p_token uuid, p_leccion text default null)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_alumno uuid := escuela.alumno_por_token(p_token);
begin
  if v_alumno is null then
    return jsonb_build_object('ok', false, 'error', 'Sesion no valida.');
  end if;

  -- Al mirarlas, quedan marcadas como vistas.
  update escuela.consultas
     set vista_por_alumno = true
   where alumno_id = v_alumno
     and respondida_en is not null
     and (p_leccion is null or leccion_slug = p_leccion);

  return jsonb_build_object(
    'ok', true,
    'consultas', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', id, 'leccion', leccion_slug, 'estacion', estacion,
               'pregunta', pregunta, 'respuesta', respuesta,
               'cuando', creado_en, 'respondida_en', respondida_en)
             order by creado_en desc)
        from escuela.consultas
       where alumno_id = v_alumno
         and (p_leccion is null or leccion_slug = p_leccion)), '[]'::jsonb)
  );
end;
$$;

-- =====================================================================
-- LADO DEL MAESTRO
-- =====================================================================

create or replace function public.ed_maestro_entrar(p_codigo text, p_clave text)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_grupo escuela.grupos%rowtype;
  v_token uuid;
begin
  select * into v_grupo from escuela.grupos where codigo = upper(btrim(p_codigo));

  if not found
     or v_grupo.maestro_clave_hash is null
     or v_grupo.maestro_clave_hash <> extensions.crypt(p_clave, v_grupo.maestro_clave_hash) then
    perform pg_sleep(0.5);
    return jsonb_build_object('ok', false, 'error', 'Codigo o clave incorrectos.');
  end if;

  delete from escuela.sesiones_maestro where expira_en < now();

  insert into escuela.sesiones_maestro (grupo_id)
  values (v_grupo.id) returning token into v_token;

  return jsonb_build_object('ok', true, 'token', v_token, 'grupo', v_grupo.nombre);
end;
$$;

create or replace function public.ed_maestro_salir(p_token uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  delete from escuela.sesiones_maestro where token = p_token;
  return jsonb_build_object('ok', true);
end;
$$;

-- ---------------------------------------------------------------------
-- Todo el tablero en una sola llamada
-- ---------------------------------------------------------------------
create or replace function public.ed_maestro_panel(p_token uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_grupo uuid := escuela.grupo_por_token_maestro(p_token);
begin
  if v_grupo is null then
    return jsonb_build_object('ok', false, 'error', 'Tu sesion vencio. Volve a entrar.');
  end if;

  return jsonb_build_object(
    'ok', true,
    'grupo', (select nombre from escuela.grupos where id = v_grupo),
    'codigo', (select codigo from escuela.grupos where id = v_grupo),

    'lecciones', coalesce((
      select jsonb_agg(jsonb_build_object(
               'slug', slug, 'titulo', titulo, 'orden', orden,
               'estrellas_max', estrellas_max,
               'disponible', (publicada_desde is null or publicada_desde <= current_date))
             order by orden)
        from escuela.lecciones), '[]'::jsonb),

    'alumnos', coalesce((
      select jsonb_agg(x order by x->>'nombre')
        from (
          select jsonb_build_object(
                   'id', a.id, 'nombre', a.nombre, 'apellido', a.apellido_inicial,
                   'activo', a.activo, 'creado_en', a.creado_en, 'ultimo_acceso', a.ultimo_acceso,
                   'estrellas', coalesce((select sum(p.estrellas) from escuela.progreso p
                                           where p.alumno_id = a.id), 0),
                   'por_leccion', coalesce((
                       select jsonb_object_agg(leccion_slug, total)
                         from (select p.leccion_slug, sum(p.estrellas) as total
                                 from escuela.progreso p where p.alumno_id = a.id
                                group by p.leccion_slug) t), '{}'::jsonb)
                 ) as x
            from escuela.alumnos a
           where a.grupo_id = v_grupo
        ) s), '[]'::jsonb),

    -- Qué estación le está costando al grupo: promedio de estrellas e intentos
    'dificultad', coalesce((
      select jsonb_agg(jsonb_build_object(
               'leccion', leccion_slug, 'estacion', estacion,
               'chicos', cuantos,
               'promedio_estrellas', round(prom_e, 2),
               'promedio_intentos', round(prom_i, 2),
               'uso_pista', pistas)
             order by prom_e asc, prom_i desc)
        from (
          select p.leccion_slug, p.estacion,
                 count(*) as cuantos,
                 avg(p.estrellas)::numeric as prom_e,
                 avg(p.intentos)::numeric  as prom_i,
                 count(*) filter (where p.uso_pista) as pistas
            from escuela.progreso p
            join escuela.alumnos a on a.id = p.alumno_id
           where a.grupo_id = v_grupo
           group by p.leccion_slug, p.estacion
        ) d), '[]'::jsonb),

    'respuestas', coalesce((
      select jsonb_agg(jsonb_build_object(
               'alumno', a.nombre, 'apellido', a.apellido_inicial,
               'leccion', r.leccion_slug, 'estacion', r.estacion,
               'texto', r.texto, 'cuando', r.actualizado_en)
             order by r.actualizado_en desc)
        from escuela.respuestas r
        join escuela.alumnos a on a.id = r.alumno_id
       where a.grupo_id = v_grupo), '[]'::jsonb),

    'consultas', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'alumno', a.nombre, 'apellido', a.apellido_inicial,
               'leccion', c.leccion_slug, 'estacion', c.estacion,
               'pregunta', c.pregunta, 'respuesta', c.respuesta,
               'cuando', c.creado_en, 'respondida_en', c.respondida_en,
               'vista', c.vista_por_alumno)
             order by (c.respondida_en is not null), c.creado_en desc)
        from escuela.consultas c
        join escuela.alumnos a on a.id = c.alumno_id
       where a.grupo_id = v_grupo), '[]'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------------
-- Responder una consulta
-- ---------------------------------------------------------------------
create or replace function public.ed_maestro_responder(
  p_token uuid, p_consulta bigint, p_respuesta text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_grupo uuid := escuela.grupo_por_token_maestro(p_token);
  v_filas int;
begin
  if v_grupo is null then
    return jsonb_build_object('ok', false, 'error', 'Tu sesion vencio. Volve a entrar.');
  end if;
  if length(btrim(coalesce(p_respuesta, ''))) = 0 then
    return jsonb_build_object('ok', false, 'error', 'La respuesta esta vacia.');
  end if;

  update escuela.consultas c
     set respuesta = left(btrim(p_respuesta), 1500),
         respondida_en = now(),
         vista_por_alumno = false
   where c.id = p_consulta
     and exists (select 1 from escuela.alumnos a
                  where a.id = c.alumno_id and a.grupo_id = v_grupo);
  get diagnostics v_filas = row_count;

  if v_filas = 0 then
    return jsonb_build_object('ok', false, 'error', 'Esa consulta no es de tu grupo.');
  end if;
  return jsonb_build_object('ok', true);
end;
$$;

-- ---------------------------------------------------------------------
-- Acciones sobre un alumno: desactivar, reactivar, reiniciar progreso
-- ---------------------------------------------------------------------
create or replace function public.ed_maestro_alumno(
  p_token uuid, p_alumno uuid, p_accion text
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_grupo uuid := escuela.grupo_por_token_maestro(p_token);
begin
  if v_grupo is null then
    return jsonb_build_object('ok', false, 'error', 'Tu sesion vencio. Volve a entrar.');
  end if;
  if not exists (select 1 from escuela.alumnos where id = p_alumno and grupo_id = v_grupo) then
    return jsonb_build_object('ok', false, 'error', 'Ese alumno no es de tu grupo.');
  end if;

  if p_accion = 'desactivar' then
    update escuela.alumnos set activo = false where id = p_alumno;
  elsif p_accion = 'activar' then
    update escuela.alumnos set activo = true where id = p_alumno;
  elsif p_accion = 'reiniciar' then
    delete from escuela.progreso  where alumno_id = p_alumno;
    delete from escuela.respuestas where alumno_id = p_alumno;
  elsif p_accion = 'borrar' then
    delete from escuela.alumnos where id = p_alumno;
  else
    return jsonb_build_object('ok', false, 'error', 'Accion desconocida.');
  end if;

  return jsonb_build_object('ok', true);
end;
$$;

-- ---------------------------------------------------------------------
-- Abrir o cerrar una misión
-- ---------------------------------------------------------------------
create or replace function public.ed_maestro_leccion(
  p_token uuid, p_slug text, p_disponible boolean
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_grupo uuid := escuela.grupo_por_token_maestro(p_token);
begin
  if v_grupo is null then
    return jsonb_build_object('ok', false, 'error', 'Tu sesion vencio. Volve a entrar.');
  end if;

  update escuela.lecciones
     set publicada_desde = case when p_disponible then null else date '2099-01-01' end
   where slug = p_slug;

  return jsonb_build_object('ok', true);
end;
$$;

-- ---------------------------------------------------------------------
-- Permisos
-- ---------------------------------------------------------------------
revoke all on function public.ed_consulta_crear(uuid, text, text, text)   from public;
revoke all on function public.ed_mis_consultas(uuid, text)                from public;
revoke all on function public.ed_maestro_entrar(text, text)               from public;
revoke all on function public.ed_maestro_salir(uuid)                      from public;
revoke all on function public.ed_maestro_panel(uuid)                      from public;
revoke all on function public.ed_maestro_responder(uuid, bigint, text)    from public;
revoke all on function public.ed_maestro_alumno(uuid, uuid, text)         from public;
revoke all on function public.ed_maestro_leccion(uuid, text, boolean)     from public;
revoke all on function escuela.grupo_por_token_maestro(uuid)              from public;

grant execute on function public.ed_consulta_crear(uuid, text, text, text) to anon;
grant execute on function public.ed_mis_consultas(uuid, text)              to anon;
grant execute on function public.ed_maestro_entrar(text, text)             to anon;
grant execute on function public.ed_maestro_salir(uuid)                    to anon;
grant execute on function public.ed_maestro_panel(uuid)                    to anon;
grant execute on function public.ed_maestro_responder(uuid, bigint, text)  to anon;
grant execute on function public.ed_maestro_alumno(uuid, uuid, text)       to anon;
grant execute on function public.ed_maestro_leccion(uuid, text, boolean)   to anon;
