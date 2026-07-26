-- =====================================================================
-- Soporte para la portada con selector de misión.
--
-- La portada necesita dos cosas que antes no existían:
--   1. cuántas estrellas tiene cada lección (para mostrar "12 de 18")
--   2. cuántas lleva el chico en cada una, en una sola llamada
--
-- Y necesita poder mostrar misiones que todavía no están listas, como
-- "próximamente", en vez de esconderlas: ver una misión bloqueada
-- motiva más que no saber que existe.
-- =====================================================================

alter table escuela.lecciones
  add column if not exists estrellas_max smallint not null default 18;

comment on column escuela.lecciones.estrellas_max is
  'Total de estrellas posibles: estaciones puntuables x 3. Hoy son 6 x 3 = 18.';

comment on column escuela.lecciones.publicada_desde is
  'NULL o fecha pasada = disponible. Fecha futura = se muestra bloqueada en la portada.';

-- La lección 5 todavía no tiene su JSON: se muestra pero no se puede abrir.
update escuela.lecciones
   set publicada_desde = date '2099-01-01'
 where slug = 'repaso-5-final';

-- ---------------------------------------------------------------------
-- Lecciones para la portada: ahora devuelve TODAS, con un booleano que
-- dice si ya se puede jugar.
-- ---------------------------------------------------------------------
create or replace function public.ed_lecciones()
returns jsonb
language sql
security definer
set search_path = ''
stable
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
           'slug',          slug,
           'titulo',        titulo,
           'tema',          tema,
           'archivo',       archivo,
           'orden',         orden,
           'estrellas_max', estrellas_max,
           'disponible',    (publicada_desde is null or publicada_desde <= current_date)
         ) order by orden), '[]'::jsonb)
    from escuela.lecciones;
$$;

-- ---------------------------------------------------------------------
-- Resumen del chico en todas las lecciones, en una sola llamada.
-- ---------------------------------------------------------------------
create or replace function public.ed_mi_resumen(p_token uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_alumno uuid := escuela.alumno_por_token(p_token);
begin
  if v_alumno is null then
    return jsonb_build_object('ok', false, 'error', 'Sesion no valida.');
  end if;

  return jsonb_build_object(
    'ok', true,
    'lecciones', coalesce((
      select jsonb_object_agg(leccion_slug, jsonb_build_object(
               'estrellas',  total,
               'estaciones', cuantas))
        from (
          select leccion_slug, sum(estrellas) as total, count(*) as cuantas
            from escuela.progreso
           where alumno_id = v_alumno
           group by leccion_slug
        ) s), '{}'::jsonb)
  );
end;
$$;

revoke all on function public.ed_mi_resumen(uuid) from public;
grant execute on function public.ed_mi_resumen(uuid) to anon;
