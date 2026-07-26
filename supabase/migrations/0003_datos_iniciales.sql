-- =====================================================================
-- Datos iniciales: el Grupo D y el repaso del primer semestre.
--
-- OJO: la clave del panel de maestro queda en NULL a propósito, para no
-- dejar una contraseña escrita en el repositorio. Mientras sea NULL,
-- ed_panel() rechaza todo. Para activarla, corré una sola vez:
--
--   update escuela.grupos
--      set maestro_clave_hash = extensions.crypt('LA-CLAVE', extensions.gen_salt('bf'))
--    where codigo = 'GRUPOD';
-- =====================================================================

insert into escuela.grupos (codigo, nombre, edad_desde, edad_hasta)
values ('GRUPOD', 'Grupo D', 10, 11)
on conflict (codigo) do nothing;

insert into escuela.lecciones (slug, titulo, tema, archivo, orden) values
  ('repaso-1-anuncios',
   'Los anuncios que cambiaron el mundo',
   'Gabriel anuncia a Zacarías y a María',
   'lecciones/repaso-1-anuncios.json', 1),

  ('repaso-2-nacimiento',
   'La noche del nacimiento',
   'El nacimiento de Jesús, los pastores y los sabios de Oriente',
   'lecciones/repaso-2-nacimiento.json', 2),

  ('repaso-3-juan',
   'El que preparó el camino',
   'Juan el Bautista: nacimiento, desierto y predicación',
   'lecciones/repaso-3-juan.json', 3),

  ('repaso-4-bautismo',
   'El bautismo de Jesús',
   'El Jordán, la paloma y la voz del Padre',
   'lecciones/repaso-4-bautismo.json', 4),

  ('repaso-5-final',
   'Desafío final del semestre',
   'Repaso general de los cuatro relatos',
   'lecciones/repaso-5-final.json', 5)
on conflict (slug) do nothing;
