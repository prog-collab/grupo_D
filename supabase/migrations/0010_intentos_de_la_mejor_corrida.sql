-- =====================================================================
-- Que `intentos` sea un número que quiera decir algo en el panel.
--
-- Hasta ahora ed_progreso_guardar hacía:
--
--     intentos = escuela.progreso.intentos + excluded.intentos
--
-- o sea que SUMABA los intentos de todas las veces que el chico hizo la
-- actividad. El que la rehacía para mejorarla quedaba con un número más
-- grande justamente por haber vuelto a intentarlo. Y esa columna no es
-- decorativa: el panel la muestra como "Intentos" en "Lo que más les
-- costó" y además la usa para ordenar la tabla (prom_e asc, prom_i desc),
-- así que una actividad que el grupo repitió mucho se trepaba a la lista
-- de las difíciles sin serlo.
--
-- El resto de la fila ya describía la MEJOR corrida —estrellas con
-- greatest(), uso_pista con and— y sólo intentos contaba otra cosa. Ahora
-- las tres cosas dicen lo mismo:
--
--     estrellas = la mejor       (greatest)
--     intentos  = los de esa     (least)
--     uso_pista = pidió pista en todas
--
-- Y lo que se perdía con la suma —cuántas veces volvió— pasa a su propia
-- columna, `veces`, que es la información que el maestro realmente quería:
-- no es lo mismo sacar 2 estrellas de una que sacarlas después de
-- intentarlo cuatro domingos seguidos.
-- =====================================================================

alter table escuela.progreso
  add column if not exists veces smallint not null default 1;

comment on column escuela.progreso.intentos is
  'Intentos de la mejor corrida, la que dio las estrellas guardadas. NO es la suma de todas las veces.';
comment on column escuela.progreso.veces is
  'Cuántas veces entregó esta actividad. 1 = la hizo una sola vez y no volvió.';

-- ---------------------------------------------------------------------
-- El guardado
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
    alumno_id, leccion_slug, estacion, estrellas, uso_pista, intentos, veces, segundos
  ) values (
    v_alumno, p_leccion, p_estacion, greatest(0, least(3, p_estrellas)),
    p_uso_pista, greatest(1, p_intentos), 1, p_segundos
  )
  on conflict (alumno_id, leccion_slug, estacion) do update
    set estrellas     = greatest(escuela.progreso.estrellas, excluded.estrellas),
        uso_pista     = escuela.progreso.uso_pista and excluded.uso_pista,
        -- la mejor corrida, no la suma
        intentos      = least(escuela.progreso.intentos, excluded.intentos),
        veces         = escuela.progreso.veces + 1,
        segundos      = coalesce(excluded.segundos, escuela.progreso.segundos),
        completado_en = now();

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.ed_progreso_guardar(uuid, text, text, smallint, boolean, smallint, integer) from public;
grant execute on function public.ed_progreso_guardar(uuid, text, text, smallint, boolean, smallint, integer) to anon;

-- ---------------------------------------------------------------------
-- Lo que ya está guardado
--
-- Las sumas viejas no se pueden deshacer: no sabemos en cuántas corridas
-- se juntaron ni cuánto puso cada una. Lo único que sí podemos hacer sin
-- inventar nada es sacar los valores IMPOSIBLES — los que no alcanzan
-- para las estrellas que la misma fila tiene guardadas.
--
-- Con la escala de 0009 (3⭐ hasta max(1, d/6) errores, 2⭐ hasta
-- max(3, d/2), y la pista descontando una), una fila con 3 estrellas no
-- pudo haber tenido más de perfecto+1 intentos. Si dice más, la suma la
-- infló: la bajamos al tope posible.
--
-- Las filas de 1 estrella no tienen tope y quedan como están. Y `veces`
-- arranca en 1 para todas porque no hay forma de saber cuántas fueron.
-- ---------------------------------------------------------------------
with decisiones (leccion_slug, estacion, d) as (values
    ('repaso-1-anuncios', 'quiz-anuncios', 8),
    ('repaso-1-anuncios', 'caza-error', 6),
    ('repaso-1-anuncios', 'linea-tiempo', 6),
    ('repaso-1-anuncios', 'versiculo', 7),
    ('repaso-1-anuncios', 'profecias', 4),
    ('repaso-1-anuncios', 'detective', 1),
    ('repaso-2-nacimiento', 'quiz-nacimiento', 8),
    ('repaso-2-nacimiento', 'caza-error', 7),
    ('repaso-2-nacimiento', 'linea-tiempo', 8),
    ('repaso-2-nacimiento', 'versiculo', 7),
    ('repaso-2-nacimiento', 'profecias', 4),
    ('repaso-2-nacimiento', 'detective', 1),
    ('repaso-3-juan', 'quiz-juan', 8),
    ('repaso-3-juan', 'caza-error', 7),
    ('repaso-3-juan', 'linea-tiempo', 8),
    ('repaso-3-juan', 'versiculo', 8),
    ('repaso-3-juan', 'profecias', 4),
    ('repaso-3-juan', 'detective', 1),
    ('repaso-4-bautismo', 'quiz-bautismo', 8),
    ('repaso-4-bautismo', 'caza-error', 7),
    ('repaso-4-bautismo', 'linea-tiempo', 8),
    ('repaso-4-bautismo', 'versiculo', 7),
    ('repaso-4-bautismo', 'quien-hizo-que', 4),
    ('repaso-4-bautismo', 'detective', 1),
    ('repaso-5-final', 'quiz-final', 10),
    ('repaso-5-final', 'caza-error', 9),
    ('repaso-5-final', 'linea-tiempo', 10),
    ('repaso-5-final', 'versiculo', 8),
    ('repaso-5-final', 'quien-lo-dijo', 6),
    ('repaso-5-final', 'detective', 1)
),
topes as (
  select p.alumno_id,
         p.leccion_slug,
         p.estacion,
         case least(3, p.estrellas + (case when p.uso_pista then 1 else 0 end))
           when 3 then greatest(1, round(v.d / 6.0))::int + 1
           when 2 then greatest(3, round(v.d / 2.0))::int + 1
           else null
         end as tope
    from escuela.progreso p
    join decisiones v
      on v.leccion_slug = p.leccion_slug
     and v.estacion     = p.estacion
)
update escuela.progreso p
   set intentos = t.tope::smallint,
       -- si la suma se pasaba del tope, es porque volvió al menos una vez
       veces    = greatest(p.veces, 2)
  from topes t
 where t.alumno_id    = p.alumno_id
   and t.leccion_slug = p.leccion_slug
   and t.estacion     = p.estacion
   and t.tope is not null
   and p.intentos     > t.tope;

-- ---------------------------------------------------------------------
-- El panel: además del promedio de intentos, cuántos chicos la rehicieron.
-- Es la señal que antes venía escondida adentro de la suma.
-- ---------------------------------------------------------------------
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

    'dificultad', coalesce((
      select jsonb_agg(jsonb_build_object(
               'leccion', leccion_slug, 'estacion', estacion,
               'chicos', cuantos,
               'promedio_estrellas', round(prom_e, 2),
               'promedio_intentos', round(prom_i, 2),
               'rehicieron', repitieron,
               'uso_pista', pistas)
             order by prom_e asc, prom_i desc)
        from (
          select p.leccion_slug, p.estacion,
                 count(*) as cuantos,
                 avg(p.estrellas)::numeric as prom_e,
                 avg(p.intentos)::numeric  as prom_i,
                 count(*) filter (where p.veces > 1)  as repitieron,
                 count(*) filter (where p.uso_pista)  as pistas
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
