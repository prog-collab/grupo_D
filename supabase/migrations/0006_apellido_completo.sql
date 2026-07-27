-- =====================================================================
-- Apellido completo al entrar.
--
-- La inicial no alcanzaba. Dos chicos del mismo nombre en el mismo grupo
-- se peleaban por la misma letra, y el que llegaba segundo terminaba
-- inventando "Gi" para que lo dejara pasar: dos fichas para la misma
-- persona. Desde acá el chico escribe el apellido entero y listo.
-- =====================================================================

alter table escuela.alumnos rename column apellido_inicial to apellido;

-- El índice único sigue a la columna renombrada; el tope de dos letras no.
-- Dejo pasar el largo 1 porque las fichas viejas todavía guardan la inicial:
-- el que exige el apellido entero de acá en más es ed_entrar.
alter table escuela.alumnos drop constraint alumnos_apellido_inicial_corto;
alter table escuela.alumnos
  add constraint alumnos_apellido_razonable
  check (apellido is null or length(btrim(apellido)) between 1 and 60);

comment on column escuela.alumnos.apellido is
  'Apellido completo. Hasta la migración 0006 era sólo la inicial; las fichas viejas se adoptan al entrar.';

-- ---------------------------------------------------------------------
-- Entrar. Cambia el nombre del parámetro, así que hay que rehacerla.
-- ---------------------------------------------------------------------
drop function if exists public.ed_entrar(text, text, text);

create function public.ed_entrar(
  p_codigo   text,
  p_nombre   text,
  p_apellido text
) returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_grupo    escuela.grupos%rowtype;
  v_alumno   escuela.alumnos%rowtype;
  v_nombre   text := btrim(coalesce(p_nombre, ''));
  v_apellido text := btrim(coalesce(p_apellido, ''));
begin
  select * into v_grupo
    from escuela.grupos
   where codigo = upper(btrim(p_codigo));

  if not found then
    return jsonb_build_object('ok', false, 'error', 'Ese código de grupo no existe.');
  end if;

  if length(v_nombre) < 2 or length(v_apellido) < 2 then
    return jsonb_build_object('ok', false, 'error', 'Escribí tu nombre y tu apellido completo.');
  end if;

  select * into v_alumno
    from escuela.alumnos
   where grupo_id = v_grupo.id
     and lower(btrim(nombre)) = lower(v_nombre)
     and lower(coalesce(apellido, '')) = lower(v_apellido);

  /* Fichas de antes de la 0006: "Giovanna G" es la misma chica que ahora
     escribe "Giovanna Giustozzi". Si hay varias (porque en su momento tuvo
     que inventarse una segunda inicial), me quedo con la que tiene más
     progreso y desactivo el resto, para que el maestro no vea duplicados
     y ella no pierda las estrellas que ya ganó. */
  if not found then
    select * into v_alumno
      from escuela.alumnos a
     where a.grupo_id = v_grupo.id
       and lower(btrim(a.nombre)) = lower(v_nombre)
       and a.apellido is not null
       and length(a.apellido) <= 2
       and lower(a.apellido) = lower(left(v_apellido, length(a.apellido)))
     order by (select count(*) from escuela.progreso p where p.alumno_id = a.id) desc,
              a.ultimo_acceso desc nulls last
     limit 1;

    if found then
      update escuela.alumnos
         set apellido = v_apellido, ultimo_acceso = now()
       where id = v_alumno.id;

      update escuela.alumnos a
         set activo = false
       where a.grupo_id = v_grupo.id
         and a.id <> v_alumno.id
         and lower(btrim(a.nombre)) = lower(v_nombre)
         and a.apellido is not null
         and length(a.apellido) <= 2
         and lower(a.apellido) = lower(left(v_apellido, length(a.apellido)));

      v_alumno.apellido := v_apellido;
    end if;
  end if;

  if v_alumno.id is null then
    insert into escuela.alumnos (grupo_id, nombre, apellido, ultimo_acceso)
    values (v_grupo.id, v_nombre, v_apellido, now())
    returning * into v_alumno;
  else
    update escuela.alumnos set ultimo_acceso = now() where id = v_alumno.id;
  end if;

  if not v_alumno.activo then
    return jsonb_build_object('ok', false, 'error', 'Hablá con tu maestro para volver a entrar.');
  end if;

  return jsonb_build_object(
    'ok',       true,
    'token',    v_alumno.token,
    'nombre',   v_alumno.nombre,
    'apellido', v_alumno.apellido,
    'grupo',    v_grupo.nombre
  );
end;
$$;

revoke all on function public.ed_entrar(text, text, text) from public;
grant execute on function public.ed_entrar(text, text, text) to anon;

-- ---------------------------------------------------------------------
-- Las dos funciones que nombraban la columna vieja adentro del cuerpo.
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
                   'apellido',      a.apellido,
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

create or replace function public.ed_maestro_panel(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_grupo uuid := escuela.grupo_por_token_maestro(p_token);
begin
  if v_grupo is null then
    return jsonb_build_object('ok', false, 'error', 'Tu sesion vencio. Volve a entrar.');
  end if;

  return jsonb_build_object(
    'ok', true,
    'grupo',  (select nombre from escuela.grupos where id = v_grupo),
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
                   'id', a.id, 'nombre', a.nombre, 'apellido', a.apellido,
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
               'alumno', a.nombre, 'apellido', a.apellido,
               'leccion', r.leccion_slug, 'estacion', r.estacion,
               'texto', r.texto, 'cuando', r.actualizado_en)
             order by r.actualizado_en desc)
        from escuela.respuestas r
        join escuela.alumnos a on a.id = r.alumno_id
       where a.grupo_id = v_grupo), '[]'::jsonb),

    'consultas', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', c.id, 'alumno', a.nombre, 'apellido', a.apellido,
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
