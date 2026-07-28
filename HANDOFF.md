# Seguir en otra máquina — Explorador Bíblico (Grupo D)

Estado al 26/07/2026. Este archivo alcanza para retomar el trabajo desde cero
en otra computadora, sin el historial de la conversación.

---

## 1. Qué es el proyecto

App de actividades para la escuela dominical del **Grupo D** (Asamblea
Cristiana), chicos de 10 y 11 años.

| | |
|---|---|
| Repo | `prog-collab/grupo_D`, rama **master** |
| Publicado en | https://prog-collab.github.io/grupo_D/ (GitHub Pages, sale solo al pushear) |
| Carpeta local | `C:\Users\juans\Claude\Projects\grupo_D` |
| Base de datos | Supabase, proyecto **camerino-giustozzi**, esquema `escuela` |
| Biblia | **Reina-Valera 1960** en todo el material, con atribución |

No hay build ni framework: es HTML + JS a mano, sin dependencias.

### Archivos

```
index.html          la app de los chicos (motor + los 8 tipos de actividad)
panel.html          el panel del maestro
lecciones/*.json    el contenido: 5 lecciones, una por archivo
sw.js               service worker (instalable + offline + los avisos al maestro)
manifest.webmanifest
supabase/migrations/*.sql   el esquema, en orden
supabase/funciones/         las funciones de borde (se despliegan a Supabase, no a Pages)
iconos/, apple-touch-icon.png
validar-lecciones.js  chequeo de contenido (ver abajo)
.claude/servidor-local.js  servidor estático para probar, no se publica
.claude/launch.json        config del preview (puerto 8899)
```

### Cómo levantarlo

Sólo hace falta **Node**. No hay `npm install`.

```bash
node .claude/servidor-local.js
```

Queda en http://localhost:8899. En Claude Code alcanza con pedir el preview
`grupo-d`, que ya está configurado en `.claude/launch.json`.

---

## 2. Cómo funciona, lo mínimo para no romper nada

- **Los chicos entran sin contraseña**: código del grupo (`GRUPOD`) + nombre +
  apellido completo. El servidor devuelve un token que queda en
  `localStorage` bajo `ed:sesion`.
- **Un teléfono puede tener varios chicos**: los que ya entraron quedan en
  `ed:perfiles` y la puerta les muestra una lista para tocar su nombre. Los
  mellizos se alternan con un toque, sin volver a escribir nada, y cada uno
  vuelve a su propio progreso.
- **Todo se guarda dos veces**: en el teléfono (`localStorage`) y en Supabase
  vía RPCs (`ed_progreso_guardar`, `ed_respuesta_guardar`, …). Si no hay
  internet, lo que no se pudo enviar queda en una cola (`ed:pendientes`) y se
  reintenta al volver la señal.
- **Las claves locales llevan adentro el dueño** (`ed:<token>:<lección>:<campo>`)
  para que dos hermanos con el mismo teléfono no se pisen el progreso.
- **`Mi oración` nunca sale del teléfono.** No la toca ninguna RPC. Es una
  promesa que le hicimos a los chicos: no romperla.
- **Las estrellas van con el tamaño de la actividad**: una equivocación cada
  seis decisiones no te saca las tres. La cuenta la hace `estrellasDe()` en
  `index.html`; el servidor sólo guarda lo que la app manda. Ver §3.1.
- **El panel del maestro** entra con código + clave (sesión de 8 horas,
  `sessionStorage` bajo `ed:maestro`).

### Modo demo (para maestros)

`index.html?demo=1`, pero se entra desde el panel con **"🧪 Probar las
actividades"** — la app exige que haya sesión de maestro en esa pestaña.

En demo: no se envía nada al servidor, nada se guarda en el teléfono (todo
vive en memoria), se entra también a las misiones cerradas, y cada actividad
tiene un botón **"🔎 Ver las respuestas"**.

### Validador de contenido

```bash
node validar-lecciones.js
```

Falla si alguna opción de "evidencia" del quiz —o alguna pista— cita un
versículo que el chico no vio antes en el expediente. **Correrlo siempre
después de tocar un JSON de lección.** Salió de un reclamo real de una alumna:
le pedían elegir Lucas 2:17 y ese versículo no estaba en la lectura.

---

## 3. Lo que se hizo en esta sesión

Dos commits, ambos ya en `master` y publicados:

1. **`52bbdda…ca8cafd` — Asegurar que toda cita del quiz esté en el expediente.**
   Había 6 citas huérfanas repartidas en las 4 lecciones (3 eran la respuesta
   correcta). Se agregaron los versículos faltantes y se sumó
   `validar-lecciones.js`.

2. **`ad067e3` — Instalable como app, panel a mano y modo demo.**
   PWA completa (manifiesto, íconos, service worker con precarga y
   recuperación si el teléfono le vacía la caché), accesos cruzados app ↔
   panel, y el modo demo descrito arriba.

Verificado en el navegador: la app abre con el servidor apagado, el demo no
hace una sola llamada al servidor ni escribe en `localStorage`, y fuera de
demo el comportamiento de los chicos no cambió.

### Misión 5 — "Desafío final"

Ya tiene su contenido (`lecciones/repaso-5-final.json`) y en la base se llama
**Desafío final** (antes "Desafío final del semestre").

Es la única que cruza las cuatro misiones anteriores: el expediente junta
todos los versículos del semestre en orden narrativo —incluida la parte de
Juan que va antes del nacimiento, que suelta no se nota— y ninguna pregunta
del quiz se contesta acordándose de una sola misión. Termina con Juan 20:31,
que es el versículo que explica para qué se escribió el resto.

Mismo formato que las otras: 6 estaciones puntuables (18 estrellas), 4 dígitos
para el cofre. El código del cofre es **1960**, por la Reina-Valera.

**No se abre para todos a la vez: se gana.** Está publicada, pero cada chico
la ve con candado hasta que termina las otras cuatro; mientras tanto le dice
cuántas le faltan. El requisito vive en la base, en `lecciones.requiere` (un
array de slugs), y quien decide es la portada con el resumen que ya pedía:
no hay una llamada extra.

"Terminada" es **haber hecho las 6 actividades puntuables**, no haber sacado
las 18 estrellas. Con la vara de las estrellas perfectas no la abriría nadie:
hoy ningún chico tiene 18 en ninguna misión, y una pista pedida en marzo lo
dejaría afuera para siempre.

El candado es de la portada, no del servidor: el JSON es un archivo estático
y cualquiera con el link entra igual. Alcanza para lo que queremos.

Si querés cerrarla del todo (que no la vea nadie hasta el día que la des),
el botón "Cerrar" del panel sigue funcionando y manda las dos cosas juntas.

---

### 3.1 Sesión del 28/07 — tres errores y la escala de estrellas

Salió de mirar los datos reales de la tabla `progreso` (35 registros, 4 chicos).

**Las opciones del versículo no se mezclaban.** El quiz mezclaba las opciones
de la pregunta pero no las de "Bien, ahora demostralo", que salían en el orden
del JSON. Y ahí la correcta es la segunda en 13 de las 21 preguntas del
semestre: el que se avivaba tocaba la segunda y acertaba el 62% sin abrir el
expediente. Justo en la parte que más nos importa. Ahora se mezclan, y como el
índice ya no sirve para encontrar el botón correcto, cada botón lleva su
`_opcion`.

**La misión 5 no decía cuáles le faltaban.** El detalle vivía en el `title`
del botón, que en un teléfono no aparece nunca: el chico veía "te faltan 2
misiones" y no tenía forma de saber cuáles. Ahora las lista con número y
nombre en la propia tarjeta.

**El diploma no se bajaba en iPhone.** Era `<a download>` sobre un data URL,
que Safari ignora (y más con la app instalada). Ponían el código, veían el
confeti, leían "se está descargando" y no les llegaba nada. Ahora el diploma
se muestra en pantalla —con el dedo apretado se guarda en Fotos, que es como
se hace en iPhone— y arriba va la hoja de compartir donde existe
(`navigator.canShare`) o la descarga donde anda.

**La escala de estrellas ahora va con el tamaño de la actividad.** Antes eran
tres estrellas sólo con cero errores, midiera lo que midiera: un
interrogatorio de cuatro preguntas con versículo pide acertar ocho veces
seguidas, y el informe escrito es una sola cosa que no se puede errar. Los
promedios lo mostraban:

| estación | ⭐ antes | intentos |
|---|---|---|
| quiz-bautismo | 1,0 | 5 |
| quiz-nacimiento / anuncios | 1,5 | 3 |
| caza-error | 1,9 | 3 |
| detective (texto) | 3,0 | 1 |

La regla nueva, dicha como se la contamos a ellos: **una equivocación cada
seis decisiones no te saca las tres estrellas.** En números, con
`d` = decisiones de la actividad (`decisionesDe()`): 3 ⭐ hasta
`max(1, d/6)` errores, 2 ⭐ hasta `max(3, d/2)`, 1 ⭐ el resto. La pista sigue
costando una estrella, ni más ni menos.

El progreso viejo se recalculó con `0009_estrellas_por_tamano.sql`. Dos cosas
para tener presentes si hay que repetirlo:

- `progreso.intentos` **se acumula** entre repeticiones (`intentos +
  excluded.intentos` en `ed_progreso_guardar`), así que el número guardado no
  es el de una corrida: el que rehízo una misión figura con más errores de los
  que tuvo. Por eso el update va con `greatest()` — puede subir estrellas,
  nunca bajarlas. (Sin ese recaudo, Giovanna perdía una estrella en
  `quiz-juan`.)
- Las decisiones de cada actividad están escritas a mano en la migración,
  contadas desde los `lecciones/*.json`. **Si cambia el contenido de una
  lección, esos números quedan viejos.**

Resultado: Giovanna pasó de 14/13/13/11 a 16/16/14/14, Juan de 15 a 17.
Nadie llegó a 18, así que el techo sigue significando algo.

### 3.2 El expediente a mano y las pistas que faltaban

**El expediente se abre desde cualquier actividad.** Medía más de dos mil
píxeles y estaba arriba de todo: cuando una actividad decía "volvé al texto y
fijate bien", el chico tenía que subir casi tres pantallas y después encontrar
dónde estaba. La mayoría no volvía, adivinaba, y se veía en los números —el
interrogatorio, que es donde más hay que leer, era lo peor puntuado. Ahora hay
un botón 📖 fijo abajo a la derecha que lo abre encima de lo que está haciendo;
cierra y sigue en la misma pregunta, sin perder el scroll. El mismo texto se
dibuja en los dos lados con `pintarPasaje()`, así que no hay copia que se
desincronice. Se cierra con la ✕, tocando el fondo o con Escape.

**Las tres actividades que no tenían pista ahora la tienen**: caza del error,
línea de tiempo y emparejar, en las cinco misiones. Son 15 pistas nuevas.

**Y el botón de pista dice lo que cuesta.** Ningún chico pidió una pista jamás
—cero en 35 actividades, varias trabadas en cuatro y cinco intentos—, y no era
que estuviera escondido: siempre estuvo abajo de las opciones. Lo que faltaba
era decir el precio, porque un precio que no conocés asusta más que uno que sí.
Ahora dice "te cuesta una estrella", y a partir del segundo error el botón se
resalta solo (`ofrecerPista`). No se abre sola: se ofrece.

Regla al escribir una pista: **señalá dónde mirar, nunca cuántas son ni en qué
posición está nada.** Las opciones se mezclan en pantalla, así que "la primera"
no significa nada, y decir la cantidad de falsas le saca la gracia a la caza
del error (la app ya la revela sola al tercer intento).

**El validador ahora también revisa las pistas**: si una manda a leer un
versículo que no está en el expediente, falla. Una pista que deja al chico
dando vueltas es peor que ninguna, y encima le costó una estrella.

De paso, un bug viejo de CSS: en la caza del error, el "porqué" de cada
afirmación era una tercera columna del flex y en un teléfono quedaban las tres
de dos palabras de ancho — justo cuando el chico está leyendo por qué se
equivocó. Ahora va debajo, a todo el ancho.

### 3.3 `intentos` quiere decir algo (0010)

`ed_progreso_guardar` hacía `intentos = intentos + excluded.intentos`: sumaba
los de todas las veces que el chico hizo la actividad, así que el que la
rehacía para mejorarla quedaba con un número más grande **por haber vuelto a
intentarlo**. Y no era una columna decorativa: el panel la muestra como
"Intentos" en *Lo que más les costó* y la usa para ordenar la tabla
(`order by prom_e asc, prom_i desc`), o sea que una actividad muy repetida se
trepaba a la lista de las difíciles sin serlo.

El resto de la fila ya describía la **mejor corrida** (estrellas con
`greatest`, `uso_pista` con `and`) y sólo `intentos` contaba otra cosa. Ahora
las tres coinciden: `intentos = least(...)`.

Lo que se perdía con la suma —cuántas veces volvió— pasa a su propia columna,
`veces`, y el panel la muestra como **"La rehicieron"**. Es la información que
el maestro realmente quería: no es lo mismo sacar 2 estrellas de una que
sacarlas después de intentarlo cuatro domingos seguidos.

Sobre los datos viejos: **las sumas no se pueden deshacer**, no sabemos en
cuántas corridas se juntaron. Lo único que hizo la migración sin inventar nada
fue sacar los valores *imposibles* — los que no alcanzan para las estrellas
que la propia fila tiene guardadas. Con la escala de 0009, una fila de 3
estrellas no pudo haber tenido más de `perfecto+1` intentos; si decía más, se
la bajó al tope. Las filas de 1 estrella no tienen tope y quedaron como
estaban. Sólo una fila resultó imposible (el `quiz-juan` de Giovanna: 3
estrellas con 3 intentos). Y `veces` arranca en 1 para todas salvo esa, porque
no hay forma de saber cuántas fueron.

Igual que 0009, la migración lleva escritas a mano las decisiones de cada
actividad: **si cambia el contenido de una lección, esos números quedan
viejos.**

### 3.4 El cofre no era tan estricto (y el aviso mentía)

El cofre comparaba el texto exacto: `codigo.value.trim() !== codigoCorrecto()`.
El chico junta los dígitos en el orden en que hace las actividades, no en el
que están en la pantalla, y los escribe así. Encima el mensaje era siempre el
mismo —"te falta el dígito de alguna estación"— aunque tuviera las cuatro
casillas amarillas completas a la vista.

Ahora abre con los cuatro números **en cualquier orden** (avisa que estaban
cambiados), ignora espacios y guiones, y cuando no abre dice qué le pasa a él:
cuántas estaciones le faltan ganar, que escribió de menos, o que esos no son
los números. El cartel rojo se borra al volver a escribir: antes quedaba
colgado con el casillero ya vacío y parecía que rechazaba lo que todavía no
había escrito.

Queda como estaba una cosa, por si algún día molesta: **el que escribe el
código correcto sin haber ganado las estaciones igual abre el cofre**. Los
dígitos sólo se ven ganando, así que para eso se lo tiene que pasar un
compañero.

### 3.5 Avisos al maestro cuando un chico pregunta (0011)

Antes había que acordarse de abrir el panel. Un chico que pregunta un martes a
la noche y recibe la respuesta el domingo ya se olvidó de qué preguntó.

Ahora, apenas entra una consulta, un disparador (`consultas_avisan_al_maestro`)
le pega con `pg_net` a la función de borde **`avisar-consulta`**, que le manda
una notificación al teléfono del maestro. Es **Web Push**: el que avisa es el
navegador de él, no hay servicio de terceros ni cuenta que pagar. Al tocar la
notificación se abre `panel.html?pregunta=<id>`, que aterriza en la solapa de
preguntas con esa pregunta resaltada.

```
chico pregunta -> insert en escuela.consultas
                    -> trigger escuela.avisar_consulta_nueva()
                       -> net.http_post a /functions/v1/avisar-consulta
                          -> ed_push_aviso(id): qué decir + a qué teléfonos
                          -> POST cifrado al navegador del maestro
```

- **Se prende desde el panel**, solapa *Preguntas*, botón "🔔 Avisarme cuando
  pregunten". Es **por aparato**: si lo prende en el celular y en la compu, le
  llega a los dos. En iPhone sólo funciona con el panel agregado a la pantalla
  de inicio (el panel lo detecta y lo explica en vez de fallar).
- Las suscripciones viven en `escuela.avisos_push`. Cuando el navegador
  contesta 404 o 410, la función borra esa fila sola: es un teléfono que
  desinstaló la app o apagó los avisos.
- El cifrado (RFC 8291) y la firma VAPID (RFC 8292) están escritos a mano en
  `supabase/funciones/avisar-consulta/push.js`, sin dependencias. Está probado
  contra el vector de ejemplo del RFC 8291: da byte por byte lo mismo.

**Los secretos no están en el repo** (es público). Viven en `vault`:

| nombre en vault | qué es |
|---|---|
| `push_vapid_privada` | la clave privada VAPID, como JWK |
| `push_aviso_secreto` | lo que el disparador le muestra a la función para identificarse |

La **pública** VAPID sí está a la vista, en `panel.html` (`VAPID_PUBLICA`): es
la que el navegador necesita para suscribirse, y tiene que ser el par de la
privada. Si algún día hay que rehacerlas, se generan las dos juntas, se sube
la privada a vault y se pega la pública en `panel.html`; todas las
suscripciones viejas dejan de servir y hay que volver a tocar el botón en cada
aparato.

La función de borde está desplegada **sin `verify_jwt`**: se autentica sola
con el secreto de la cabecera `x-aviso-secreto`. Si el secreto no está en
vault, el disparador no avisa y no rompe nada: la pregunta del chico se guarda
igual.

**Ojo con los permisos de las funciones nuevas (0012).** El `revoke all ...
from public` que usa todo el esquema **no alcanza**: Supabase le da `execute` a
`anon` y `authenticated` sobre las funciones nuevas de `public` por privilegios
por defecto. Como 0011 no lo sabía, `ed_push_aviso` —que devuelve la clave
privada VAPID— quedó un rato al alcance de cualquiera con la clave publicable,
que está a la vista en `index.html`. 0012 lo cierra por dos lados: revoca
`execute` a `anon` y `authenticated` **por nombre**, y además `ed_push_aviso`
ahora exige el secreto como argumento y ya no lo devuelve.

Si mañana agregás una función que no tiene que ver el chico, revocásela a
`anon` y `authenticated` explícitamente, y comprobalo:

```sql
select p.proname, has_function_privilege('anon', p.oid, 'execute')
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname like 'ed_%';
```

---

## 4. Lo que falta: el video para los chicos

Juan quiere un video de ~3 minutos contándoles de la app y cómo usarla.

### 4.1 Guion

Locución de ~400 palabras ≈ 2:50–3:00 a ritmo normal. Tono: como le hablás a
los chicos el domingo, sin infantilizar. Los tiempos son orientativos.

| Tiempo | Qué se dice | Qué se ve |
|---|---|---|
| 0:00 | ¿Te acordás de las hojas que repartíamos los domingos? Bueno, se acabaron. Ahora todo esto entra en tu teléfono. | Vos a cámara |
| 0:12 | Se llama **Explorador Bíblico**, y es una app con misiones. Cada misión es una historia de la Biblia, pero contada como un caso para resolver. | El ícono de la app / la portada |
| 0:22 | Para entrar no necesitás ni contraseña ni correo. Ponés el código del grupo, que es **GRUPOD**, tu nombre y tu apellido. Listo, ya estás adentro. Y si compartís el teléfono con un hermano, los dos pueden entrar: después cada uno toca su nombre y va a lo suyo. | **Captura 1**: la puerta de entrada, con los campos llenándose |
| 0:38 | Lo primero que te conviene hacer es instalarla. Si tenés Android, te va a aparecer un botón que dice "Instalar la app en el teléfono": tocalo y te queda con su ícono, como cualquier otra app. Si tenés iPhone, tocá el botón de compartir en Safari y elegí "Agregar a pantalla de inicio". | **Captura 2**: el botón azul de instalar; después, el ícono en la pantalla del teléfono |
| 0:56 | Y una vez instalada, abre aunque te quedes sin datos. Podés hacer las actividades en el colectivo. | Modo avión y la app abriendo igual |
| 1:04 | Adentro vas a ver las misiones. Están numeradas, pero las hacés en el orden que quieras, y podés dejar una por la mitad y volver mañana: se guarda todo. | **Captura 3**: la portada con las 4 misiones y las barras de progreso |
| 1:16 | Cuando entrás a una misión, lo primero es **el expediente**. Ahí está el relato y los versículos. No lo saltees: todas las preguntas se responden con eso. Y si después, en el medio de una actividad, necesitás volver a mirarlo, no hace falta que subas: abajo a la derecha hay un botón 📖 que te lo abre encima y te deja donde estabas. | **Captura 4**: el expediente, y después el botón 📖 abriéndolo desde una pregunta |
| 1:30 | Después vienen las actividades. Hay de todo: un interrogatorio con preguntas, una caza del error donde marcás lo que la gente repite pero no está en la Biblia, una línea de tiempo para ordenar, y un versículo para armar como rompecabezas. | **Capturas 5-8**: una de cada tipo, cortitas |
| 1:48 | Cada actividad te da hasta **tres estrellas**. Y no hace falta que te salga perfecto: una equivocación cada tanto no te las saca. La pista también está ahí si la necesitás: te va a costar una estrella, pero es mejor entender que adivinar. | El contador de estrellas arriba; el botón 💡 |
| 2:04 | Y ojo con esto, que es lo más importante: cuando acertás una pregunta, te voy a pedir **el versículo**. No alcanza con saber la respuesta, tenés que poder mostrar dónde dice. | **Captura 9**: el cuadro celeste "Bien. Ahora demostralo" |
| 2:18 | Si algo no se entiende, no te quedes trabado. Abajo de cada actividad hay un botón que dice **"No entiendo esta actividad"**. Escribís tu duda y me llega a mí. Te contesto ahí mismo, y sólo lo vemos vos y yo. | **Captura 10**: el botón 🙋 y la cajita para escribir |
| 2:34 | Hay una parte que se llama **Mi oración**. Eso no me llega. Queda en tu teléfono y no lo lee nadie más. Es entre vos y Dios. | **Captura 11**: la sección con el candado 🔒 |
| 2:44 | Y cuando terminás las actividades, cada una te da un dígito. Los cuatro juntos abren **el cofre**, y el cofre te da tu diploma con tu nombre. Te aparece ahí mismo: tocá el botón para guardarlo, o mantené el dedo apretado sobre el diploma. | **Captura 12**: el cofre y el diploma |
| 2:56 | Así que ya sabés: entrá, instalala y empezá por la misión que quieras. Nos vemos el domingo. | Vos a cámara |

**Cosas que el guion dice y conviene no cambiar**, porque son promesas que la
app cumple: que la oración no la ve nadie, que la pregunta al maestro es
privada, y que hay que mostrar el versículo.

### 4.2 Cómo conseguir las imágenes

La forma más rápida y la que mejor queda: **grabar la pantalla del teléfono
usando el modo demo**. Entrás por el panel → "🧪 Probar las actividades",
grabás la pantalla mientras recorrés las misiones, y después recortás los
pedazos. Ventajas: se ve el dedo tocando y las animaciones (el confeti, las
estrellas), y **no ensucia ningún dato** — el demo no guarda nada.

Ojo con dos cosas al grabar en demo:
- Arriba queda la **banda violeta de "Modo demo"**: recortarla o taparla.
- El botón "🔎 Ver las respuestas" aparece en cada actividad: no mostrarlo.

Si preferís capturas fijas, hay que sacarlas con una sesión de alumno normal
(la banda no aparece), pero entonces conviene usar un nombre de prueba y
después borrarlo desde el panel con "Reiniciar".

### 4.3 Sobre la edición: qué se puede y qué no

**No puedo editar el video.** No hay `ffmpeg` ni ningún editor instalado en la
máquina de Juan (chequeado), no puedo grabar audio ni sincronizar voz con
imagen. Tampoco puedo guardar las capturas del navegador como archivos: las
puedo mostrar en pantalla para revisar el encuadre, pero no dejarlas en disco.

**Lo que sí es posible**, si en la máquina nueva se instala `ffmpeg`:
- Vos grabás sólo el audio de la locución (un `.mp3`).
- Vos sacás las capturas o el screencast.
- Yo armo el montaje: capturas sincronizadas con los tiempos del guion,
  fundidos simples, y el audio encima. Sale un `.mp4` listo.

Eso es armado automático, no edición fina: si querés zooms, música o
subtítulos animados, conviene CapCut o similar, que además se maneja desde el
teléfono.

**Decisión pendiente de Juan**: si instala `ffmpeg` y vamos por el montaje
automático, o si edita él con el guion y el storyboard de arriba.

---

## 5. Cosas que no tengo

- **La clave del panel del maestro.** Todo lo del panel se verificó inyectando
  datos de prueba en el navegador; Juan confirmó que funciona bien con su clave.
- **`ffmpeg`, ImageMagick, editor de video.** Ver 4.3.
- El conector de Supabase pide autorización por sesión; si hace falta tocar la
  base, Juan tiene que autorizarlo de nuevo en la máquina nueva.

## 6. Si retomás el trabajo, arrancá por acá

```bash
git pull --rebase
node validar-lecciones.js
node .claude/servidor-local.js
```

Y despues de tocar cualquier `lecciones/*.json`, correr el validador antes de
pushear. El push a `master` va directo: publica solo en GitHub Pages.
