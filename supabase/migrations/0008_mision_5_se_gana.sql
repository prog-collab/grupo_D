-- =====================================================================
-- La misión 5 se abre, pero no para todos a la vez: sólo para el que ya
-- terminó las otras cuatro. Hasta entonces la ve con candado y con la
-- cuenta de lo que le falta.
--
-- "Terminó" es haber hecho las actividades puntuables, NO haber sacado
-- las 18 estrellas. Con la vara de las estrellas perfectas hoy no la
-- abriría nadie: ningún chico tiene 18 en ninguna misión, y una sola
-- pista pedida en marzo lo dejaría afuera para siempre. Se premia llegar
-- hasta el final, no no haberse equivocado nunca.
--
-- El candado es de la portada, no del servidor: el JSON de la lección es
-- un archivo estático y cualquiera con el link entra igual. Alcanza para
-- lo que queremos, que es que la misión 5 se sienta ganada.
-- =====================================================================

alter table escuela.lecciones
  add column if not exists requiere text[] not null default '{}';

comment on column escuela.lecciones.requiere is
  'Slugs de lecciones que el alumno tiene que haber terminado para que ésta se le abra. Vacío = se abre para todos.';

update escuela.lecciones
   set publicada_desde = null,
       requiere = array['repaso-1-anuncios','repaso-2-nacimiento','repaso-3-juan','repaso-4-bautismo']
 where slug = 'repaso-5-final';

-- ed_lecciones ahora informa el requisito. El cálculo de si un chico lo
-- cumple lo hace la app, que ya tiene su resumen: así no agregamos una
-- llamada más a la portada.
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
           'requiere',      to_jsonb(requiere),
           'disponible',    (publicada_desde is null or publicada_desde <= current_date)
         ) order by orden), '[]'::jsonb)
    from escuela.lecciones;
$$;
