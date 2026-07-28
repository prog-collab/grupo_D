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
sw.js               service worker (instalable + offline)
manifest.webmanifest
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

Falla si alguna opción de "evidencia" del quiz cita un versículo que el chico
no vio antes en el expediente. **Correrlo siempre después de tocar un JSON de
lección.** Salió de un reclamo real de una alumna: le pedían elegir Lucas 2:17
y ese versículo no estaba en la lectura.

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
| 1:16 | Cuando entrás a una misión, lo primero es **el expediente**. Ahí está el relato y los versículos. No lo saltees: todas las preguntas se responden con eso. | **Captura 4**: el expediente con los versículos |
| 1:30 | Después vienen las actividades. Hay de todo: un interrogatorio con preguntas, una caza del error donde marcás lo que la gente repite pero no está en la Biblia, una línea de tiempo para ordenar, y un versículo para armar como rompecabezas. | **Capturas 5-8**: una de cada tipo, cortitas |
| 1:48 | Cada actividad te da hasta **tres estrellas**. Tres si te sale sin equivocarte y sin pedir pista. Igual la pista está ahí si la necesitás: te va a costar una estrella, pero es mejor entender que adivinar. | El contador de estrellas arriba; el botón 💡 |
| 2:04 | Y ojo con esto, que es lo más importante: cuando acertás una pregunta, te voy a pedir **el versículo**. No alcanza con saber la respuesta, tenés que poder mostrar dónde dice. | **Captura 9**: el cuadro celeste "Bien. Ahora demostralo" |
| 2:18 | Si algo no se entiende, no te quedes trabado. Abajo de cada actividad hay un botón que dice **"No entiendo esta actividad"**. Escribís tu duda y me llega a mí. Te contesto ahí mismo, y sólo lo vemos vos y yo. | **Captura 10**: el botón 🙋 y la cajita para escribir |
| 2:34 | Hay una parte que se llama **Mi oración**. Eso no me llega. Queda en tu teléfono y no lo lee nadie más. Es entre vos y Dios. | **Captura 11**: la sección con el candado 🔒 |
| 2:44 | Y cuando terminás las actividades, cada una te da un dígito. Los cuatro juntos abren **el cofre**, y el cofre te da tu diploma con tu nombre. | **Captura 12**: el cofre y el diploma |
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
