-- =====================================================================
-- Misión 5: ya tiene su contenido (lecciones/repaso-5-final.json).
--
-- Se le saca "del semestre" del título: en la portada, al lado de las
-- otras cuatro, "Desafío final" se lee mejor y no compite con el
-- subtítulo, que ya explica de qué se trata.
--
-- Queda CERRADA a propósito (publicada_desde sigue en 2099). La abre el
-- maestro desde el panel el día que la da en clase, con el botón
-- "Abrir" de la sección de misiones. Hasta entonces se ve en la portada
-- con candado, que es lo que queremos: saber que existe motiva.
-- =====================================================================

update escuela.lecciones
   set titulo = 'Desafío final',
       tema   = 'Todo el semestre junto: las preguntas cruzan de un relato a otro'
 where slug = 'repaso-5-final';
