-- =====================================================================
-- Escuela Dominical - Asamblea Cristiana - Grupo D (10-11 años)
-- Esquema inicial: progreso, respuestas y panel de maestro.
--
-- Decisiones de privacidad (datos de menores):
--   * Todo vive en el esquema `escuela`, que NO se expone por PostgREST.
--     Nadie puede leer las tablas con la anon key, ni siquiera listarlas.
--   * El único acceso es vía las funciones `public.ed_*` (SECURITY DEFINER),
--     que validan credencial propia en cada llamada.
--   * Los chicos no tienen cuenta ni contraseña: entran con el código del
--     grupo + su nombre, y el dispositivo guarda un token opaco.
--   * La oración personal NO se guarda acá. Queda en el teléfono del chico.
--     Hay un CHECK que lo impide a nivel base, no sólo por convención.
-- =====================================================================

create extension if not exists pgcrypto with schema extensions;

create schema if not exists escuela;

-- ---------------------------------------------------------------------
-- Grupos
-- ---------------------------------------------------------------------
create table escuela.grupos (
  id                 uuid primary key default gen_random_uuid(),
  codigo             text not null unique,
  nombre             text not null,
  edad_desde         smallint,
  edad_hasta         smallint,
  maestro_clave_hash text,
  creado_en          timestamptz not null default now()
);

comment on column escuela.grupos.codigo is 'Lo que el chico tipea para entrar. Mayúsculas, sin espacios.';
comment on column escuela.grupos.maestro_clave_hash is 'bcrypt. Clave del panel de maestro.';

-- ---------------------------------------------------------------------
-- Alumnos
-- ---------------------------------------------------------------------
create table escuela.alumnos (
  id               uuid primary key default gen_random_uuid(),
  grupo_id         uuid not null references escuela.grupos(id) on delete cascade,
  nombre           text not null,
  apellido_inicial text,
  token            uuid not null unique default gen_random_uuid(),
  activo           boolean not null default true,
  creado_en        timestamptz not null default now(),
  ultimo_acceso    timestamptz,
  constraint alumnos_nombre_no_vacio check (length(btrim(nombre)) between 2 and 40),
  constraint alumnos_apellido_inicial_corto check (apellido_inicial is null or length(apellido_inicial) <= 2)
);

-- Un mismo chico no se registra dos veces en el mismo grupo.
create unique index alumnos_unicos_por_grupo
  on escuela.alumnos (grupo_id, lower(btrim(nombre)), lower(coalesce(apellido_inicial, '')));

create index alumnos_por_grupo on escuela.alumnos (grupo_id);

-- ---------------------------------------------------------------------
-- Lecciones (el contenido real vive en el repo, en lecciones/*.json)
-- ---------------------------------------------------------------------
create table escuela.lecciones (
  slug             text primary key,
  titulo           text not null,
  tema             text,
  archivo          text,
  orden            smallint,
  publicada_desde  date,
  creado_en        timestamptz not null default now()
);

comment on table escuela.lecciones is 'Índice de lecciones. Las preguntas y textos están en lecciones/*.json del repo.';

-- ---------------------------------------------------------------------
-- Progreso por estación
-- ---------------------------------------------------------------------
create table escuela.progreso (
  id            bigint generated always as identity primary key,
  alumno_id     uuid not null references escuela.alumnos(id) on delete cascade,
  leccion_slug  text not null references escuela.lecciones(slug) on delete cascade,
  estacion      text not null,
  estrellas     smallint not null default 0,
  uso_pista     boolean not null default false,
  intentos      smallint not null default 0,
  segundos      integer,
  completado_en timestamptz not null default now(),
  constraint progreso_estrellas_validas check (estrellas between 0 and 3),
  constraint progreso_intentos_validos check (intentos >= 0),
  unique (alumno_id, leccion_slug, estacion)
);

create index progreso_por_leccion on escuela.progreso (leccion_slug, alumno_id);

-- ---------------------------------------------------------------------
-- Respuestas escritas (razonamiento). NUNCA oraciones.
-- ---------------------------------------------------------------------
create table escuela.respuestas (
  id             bigint generated always as identity primary key,
  alumno_id      uuid not null references escuela.alumnos(id) on delete cascade,
  leccion_slug   text not null references escuela.lecciones(slug) on delete cascade,
  estacion       text not null,
  texto          text not null,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  constraint respuestas_texto_razonable check (length(texto) <= 2000),
  -- Guardarraíl: la oración personal no entra en la base.
  constraint respuestas_sin_oracion check (estacion not in ('oracion', 'mi-oracion', 'prayer')),
  unique (alumno_id, leccion_slug, estacion)
);

create index respuestas_por_leccion on escuela.respuestas (leccion_slug, estacion);

-- ---------------------------------------------------------------------
-- RLS: cerrado por completo. Sólo service_role y las funciones
-- SECURITY DEFINER de abajo tocan estas tablas.
-- ---------------------------------------------------------------------
alter table escuela.grupos     enable row level security;
alter table escuela.alumnos    enable row level security;
alter table escuela.lecciones  enable row level security;
alter table escuela.progreso   enable row level security;
alter table escuela.respuestas enable row level security;

revoke all on all tables in schema escuela from anon, authenticated;
revoke all on schema escuela from anon, authenticated;
