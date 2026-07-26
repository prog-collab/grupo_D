-- =====================================================================
-- Capa de acceso. Las tablas de `escuela` no se exponen; la app sólo
-- puede llamar a estas funciones con la anon key.
-- Todas son SECURITY DEFINER con search_path fijo y validan credencial.
-- =====================================================================

-- ---------------------------------------------------------------------
-- Entrar: registra al chico o lo recupera si ya existe. Devuelve token.
-- ---------------------------------------------------------------------
create or replace function public.ed_entrar(
  p_codigo           text,
  p_nombre           text,
  p_apellido_inicial text default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_grupo   escuela.grupos%rowtype;
  v_alumno  escuela.alumnos%rowtype;
begin
  select * into v_grupo
    from escuela.grupos
   where codigo = upper(btrim(p_codigo));

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Ese código de grupo no existe.');
  end if;

  select * into v_alumno
    from escuela.alumnos
   where grupo_id = v_grupo.id
     and lower(btrim(nombre)) = lower(btrim(p_nombre))
     and lower(coalesce(apellido_inicial, '')) = lower(coalesce(btrim(p_apellido_inicial), ''));

  if not found then
    insert into escuela.alumnos (grupo_id, nombre, apellido_inicial, ultimo_acceso)
    values (v_grupo.id, btrim(p_nombre), nullif(btrim(p_apellido_inicial), ''), now())
    returning * into v_alumno;
  else
    update escuela.alumnos set ultimo_acceso = now() where id = v_alumno.id;
  end if;

  if not v_alumno.activo then
    return jsonb_build_object('ok', false, 'error', 'Hablá con tu maestro para volver a entrar.');
  end if;

  return jsonb_build_object(
    'ok',     true,
    'token',  v_alumno.token,
    'nombre', v_alumno.nombre,
    'grupo',  v_grupo.nombre
  );
end;
$$;

-- ---------------------------------------------------------------------
-- Resolver token -> alumno (interna)
-- ---------------------------------------------------------------------
create or replace function escuela.alumno_por_token(p_token uuid)
returns uuid
language sql
security definer
set search_path = ''
stable
as $$
  select id from escuela.alumnos where token = p_token and activo;
$$;

-- ---------------------------------------------------------------------
-- Guardar progreso de una estación (idempotente: se queda con lo mejor)
-- ---------------------------------------------------------------------
create or replace function public.ed_progreso_guardar(
  p_token     uuid,
  p_leccion   text,
  p_estacion  text,
  p_estrellas smallint,
  p_uso_pista boolean default false,
  p_intentos  smallint default 1,
  p_segundos  integer default null
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alumno uuid := escuela.alumno_por_token(p_token);
begin
  if v_alumno is null then
    return jsonb_build_object('ok', false, 'error', 'Sesión no válida.');
  end if;

  insert into escuela.progreso (
    alumno_id, leccion_slug, estacion, estrellas, uso_pista, intentos, segundos
  ) values (
    v_alumno, p_leccion, p_estacion, greatest(0, least(3, p_estrellas)),
    p_uso_pista, greatest(0, p_intentos), p_segundos
  )
  on conflict (alumno_id, leccion_slug, estacion) do update
    set estrellas     = greatest(escuela.progreso.estrellas, excluded.estrellas),
        uso_pista     = escuela.progreso.uso_pista and excluded.uso_pista,
        intentos      = escuela.progreso.intentos + excluded.intentos,
        segundos      = coalesce(excluded.segundos, escuela.progreso.segundos),
        completado_en = now();

  return jsonb_build_object('ok', true);
end;
$$;

-- ---------------------------------------------------------------------
-- Guardar una respuesta escrita (el CHECK de la tabla bloquea oraciones)
-- ---------------------------------------------------------------------
create or replace function public.ed_respuesta_guardar(
  p_token    uuid,
  p_leccion  text,
  p_estacion text,
  p_texto    text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alumno uuid := escuela.alumno_por_token(p_token);
begin
  if v_alumno is null then
    return jsonb_build_object('ok', false, 'error', 'Sesión no válida.');
  end if;

  insert into escuela.respuestas (alumno_id, leccion_slug, estacion, texto)
  values (v_alumno, p_leccion, p_estacion, left(btrim(p_texto), 2000))
  on conflict (alumno_id, leccion_slug, estacion) do update
    set texto = excluded.texto, actualizado_en = now();

  return jsonb_build_object('ok', true);
exception
  when check_violation then
    return jsonb_build_object('ok', false, 'error', 'Esa actividad no se guarda en el servidor.');
end;
$$;

-- ---------------------------------------------------------------------
-- Estado del chico en una lección (para retomar donde dejó)
-- ---------------------------------------------------------------------
create or replace function public.ed_mi_estado(p_token uuid, p_leccion text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alumno uuid := escuela.alumno_por_token(p_token);
begin
  if v_alumno is null then
    return jsonb_build_object('ok', false, 'error', 'Sesión no válida.');
  end if;

  return jsonb_build_object(
    'ok', true,
    'estaciones', coalesce((
      select jsonb_object_agg(estacion, jsonb_build_object(
               'estrellas', estrellas, 'uso_pista', uso_pista, 'intentos', intentos))
        from escuela.progreso
       where alumno_id = v_alumno and leccion_slug = p_leccion), '{}'::jsonb),
    'respuestas', coalesce((
      select jsonb_object_agg(estacion, texto)
        from escuela.respuestas
       where alumno_id = v_alumno and leccion_slug = p_leccion), '{}'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------------
-- Lecciones publicadas
-- ---------------------------------------------------------------------
create or replace function public.ed_lecciones()
returns jsonb
language sql
security definer
set search_path = ''
stable
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'slug', slug, 'titulo', titulo, 'tema', tema,
           'archivo', archivo, 'orden', orden) order by orden), '[]'::jsonb)
    from escuela.lecciones
   where publicada_desde is null or publicada_desde <= current_date;
$$;

-- ---------------------------------------------------------------------
-- Panel del maestro. Requiere la clave del grupo.
-- ---------------------------------------------------------------------
create or replace function public.ed_panel(p_codigo text, p_clave text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_grupo escuela.grupos%rowtype;
begin
  select * into v_grupo from escuela.grupos where codigo = upper(btrim(p_codigo));

  if not found
     or v_grupo.maestro_clave_hash is null
     or v_grupo.maestro_clave_hash <> extensions.crypt(p_clave, v_grupo.maestro_clave_hash) then
    perform pg_sleep(0.5);  -- desalienta fuerza bruta
    return jsonb_build_object('ok', false, 'error', 'Código o clave incorrectos.');
  end if;

  return jsonb_build_object(
    'ok', true,
    'grupo', v_grupo.nombre,
    'alumnos', coalesce((
      select jsonb_agg(x order by x->>'nombre')
        from (
          select jsonb_build_object(
                   'nombre',        a.nombre,
                   'apellido',      a.apellido_inicial,
                   'ultimo_acceso', a.ultimo_acceso,
                   'estrellas',     coalesce((select sum(p.estrellas) from escuela.progreso p
                                               where p.alumno_id = a.id), 0),
                   'lecciones',     coalesce((select count(distinct p.leccion_slug) from escuela.progreso p
                                               where p.alumno_id = a.id), 0),
                   'respuestas',    coalesce((
                       select jsonb_agg(jsonb_build_object(
                                'leccion', r.leccion_slug, 'estacion', r.estacion,
                                'texto', r.texto, 'cuando', r.actualizado_en)
                              order by r.actualizado_en desc)
                         from escuela.respuestas r where r.alumno_id = a.id), '[]'::jsonb)
                 ) as x
            from escuela.alumnos a
           where a.grupo_id = v_grupo.id and a.activo
        ) s), '[]'::jsonb)
  );
end;
$$;

-- ---------------------------------------------------------------------
-- Permisos: la app usa la anon key y sólo puede ejecutar esto.
-- ---------------------------------------------------------------------
revoke all on function public.ed_entrar(text, text, text) from public;
revoke all on function public.ed_progreso_guardar(uuid, text, text, smallint, boolean, smallint, integer) from public;
revoke all on function public.ed_respuesta_guardar(uuid, text, text, text) from public;
revoke all on function public.ed_mi_estado(uuid, text) from public;
revoke all on function public.ed_lecciones() from public;
revoke all on function public.ed_panel(text, text) from public;
revoke all on function escuela.alumno_por_token(uuid) from public;

grant execute on function public.ed_entrar(text, text, text) to anon;
grant execute on function public.ed_progreso_guardar(uuid, text, text, smallint, boolean, smallint, integer) to anon;
grant execute on function public.ed_respuesta_guardar(uuid, text, text, text) to anon;
grant execute on function public.ed_mi_estado(uuid, text) to anon;
grant execute on function public.ed_lecciones() to anon;
grant execute on function public.ed_panel(text, text) to anon;
