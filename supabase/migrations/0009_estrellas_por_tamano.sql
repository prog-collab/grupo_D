-- =====================================================================
-- La exigencia va con el tamaño de la actividad, y lo ya jugado se
-- recalcula con la regla nueva.
--
-- La regla vieja daba las tres estrellas sólo con CERO errores, midiera
-- lo que midiera la actividad. Un interrogatorio de cuatro preguntas con
-- versículo son ocho decisiones seguidas sin fallar; el informe escrito
-- es una sola y no se puede errar. Los números lo mostraban:
--
--     quiz-bautismo    1,0 ⭐   (5 intentos)
--     quiz-nacimiento  1,5 ⭐
--     quiz-anuncios    1,5 ⭐
--     caza-error       1,9 ⭐
--     detective        3,0 ⭐   (siempre)
--
-- Ningún chico tenía las 18 estrellas de ninguna misión, y la que peor
-- puntuaba era justo la actividad donde más se lee.
--
-- La regla nueva, dicha como se la contamos a ellos: una equivocación
-- cada seis decisiones no te saca las tres estrellas.
--
--     3 ⭐ : errores <= max(1, decisiones/6)
--     2 ⭐ : errores <= max(3, decisiones/2)
--     1 ⭐ : el resto
--     la pista sigue costando una estrella, ni más ni menos
--
-- Dos avisos sobre este recálculo:
--
--  1. La app manda las estrellas ya calculadas; el servidor sólo las
--     guarda. Así que esto es para el progreso VIEJO nada más: de acá en
--     adelante la cuenta la hace index.html con la misma fórmula.
--
--  2. escuela.progreso.intentos se ACUMULA entre repeticiones
--     (intentos + excluded.intentos en ed_progreso_guardar), así que el
--     número guardado no es el de una corrida sola: el que rehízo una
--     misión para mejorarla figura con más errores de los que tuvo. Por
--     eso el update va con greatest(): puede subirle las estrellas a
--     alguien, nunca bajárselas. Al que quede corto le alcanza con
--     rehacer la actividad para que la app se las dé bien.
--
-- Las decisiones de cada actividad salen contadas de los lecciones/*.json
-- (preguntas + evidencias, afirmaciones, eventos, pares, piezas).
-- =====================================================================

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
recalculo as (
  select p.alumno_id,
         p.leccion_slug,
         p.estacion,
         greatest(1,
           (case
              when greatest(0, p.intentos - 1) <= greatest(1, round(v.d / 6.0)) then 3
              when greatest(0, p.intentos - 1) <= greatest(3, round(v.d / 2.0)) then 2
              else 1
            end) - (case when p.uso_pista then 1 else 0 end)
         )::smallint as nuevas
    from escuela.progreso p
    join decisiones v
      on v.leccion_slug = p.leccion_slug
     and v.estacion     = p.estacion
)
update escuela.progreso p
   set estrellas = r.nuevas
  from recalculo r
 where r.alumno_id    = p.alumno_id
   and r.leccion_slug = p.leccion_slug
   and r.estacion     = p.estacion
   and r.nuevas       > p.estrellas;
