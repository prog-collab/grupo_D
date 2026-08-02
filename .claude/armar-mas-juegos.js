/* Arma juegos/mas-juegos.json.
   Los versículos del semestre se copian de lecciones/*.json para que el texto
   sea exactamente el que leyeron los chicos (Reina-Valera 1960) y no una
   versión escrita de memoria. Los de "Biblia general" están acá a mano.
   Correr desde la raíz del repo:  node <este archivo> */
"use strict";
const fs = require("fs");
const path = require("path");

const RAIZ = process.argv[2] || ".";
const MIS = {
  "repaso-1-anuncios.json": 1,
  "repaso-2-nacimiento.json": 2,
  "repaso-3-juan.json": 3,
  "repaso-4-bautismo.json": 4
};

/* ---------- versículos del semestre, sacados del expediente ---------- */
const delSemestre = [];
const vistos = new Set();
for (const f of Object.keys(MIS)) {
  const j = JSON.parse(fs.readFileSync(path.join(RAIZ, "lecciones", f), "utf8"));
  j.estaciones[0].bloques.forEach(b => b.versiculos.forEach(v => {
    if (vistos.has(v.ref)) return;
    vistos.add(v.ref);
    /* Los que en el expediente están recortados con "…" no sirven para la
       carrera: el chico lee su Biblia y no coincide con la pantalla. */
    if (v.texto.includes("…")) return;
    delSemestre.push({ ref: v.ref, texto: v.texto, mision: MIS[f], origen: "semestre" });
  }));
}

/* ---------- versículos conocidos de toda la Biblia ---------- */
const generales = [
  ["Génesis 1:1", "En el principio creó Dios los cielos y la tierra."],
  ["Salmos 23:1", "Jehová es mi pastor; nada me faltará."],
  ["Salmos 119:105", "Lámpara es a mis pies tu palabra, y lumbrera a mi camino."],
  ["Proverbios 3:5", "Fíate de Jehová de todo tu corazón, y no te apoyes en tu propia prudencia."],
  ["Josué 1:9", "Mira que te mando que te esfuerces y seas valiente; no temas ni desmayes, porque Jehová tu Dios estará contigo en dondequiera que vayas."],
  ["Isaías 41:10", "No temas, porque yo estoy contigo; no desmayes, porque yo soy tu Dios que te esfuerzo; siempre te ayudaré, siempre te sustentaré con la diestra de mi justicia."],
  ["Mateo 6:33", "Mas buscad primeramente el reino de Dios y su justicia, y todas estas cosas os serán añadidas."],
  ["Mateo 28:19", "Por tanto, id, y haced discípulos a todas las naciones, bautizándolos en el nombre del Padre, y del Hijo, y del Espíritu Santo."],
  ["Marcos 10:14", "Dejad a los niños venir a mí, y no se lo impidáis; porque de los tales es el reino de Dios."],
  ["Juan 3:16", "Porque de tal manera amó Dios al mundo, que ha dado a su Hijo unigénito, para que todo aquel que en él cree, no se pierda, mas tenga vida eterna."],
  ["Juan 14:6", "Jesús le dijo: Yo soy el camino, y la verdad, y la vida; nadie viene al Padre, sino por mí."],
  ["Juan 20:31", "Pero éstas se han escrito para que creáis que Jesús es el Cristo, el Hijo de Dios, y para que creyendo, tengáis vida en su nombre."],
  ["Romanos 3:23", "Por cuanto todos pecaron, y están destituidos de la gloria de Dios."],
  ["Romanos 8:28", "Y sabemos que a los que aman a Dios, todas las cosas les ayudan a bien, esto es, a los que conforme a su propósito son llamados."],
  ["Efesios 6:1", "Hijos, obedeced en el Señor a vuestros padres, porque esto es justo."],
  ["Filipenses 4:13", "Todo lo puedo en Cristo que me fortalece."],
  ["1 Juan 1:9", "Si confesamos nuestros pecados, él es fiel y justo para perdonar nuestros pecados, y limpiarnos de toda maldad."],
  ["Apocalipsis 3:20", "He aquí, yo estoy a la puerta y llamo; si alguno oye mi voz y abre la puerta, entraré a él, y cenaré con él, y él conmigo."]
].map(([ref, texto]) => ({ ref, texto, origen: "biblia" }));

/* ============================================================
   ¿QUIÉN SOY? — las pistas van de la más difícil a la más obvia.
   La primera no puede nombrar a nadie del entorno ni el lugar famoso:
   si la pista 1 ya se contesta sola, el juego no tiene riesgo.
   ============================================================ */
const personajes = [
  { nombre: "Zacarías", mision: 1, cita: "Lucas 1:5-20, 63-64",
    remate: "Le pidió una tablilla y escribió “Juan es su nombre”. Ahí se le soltó la lengua.",
    pistas: [
      "Estaba trabajando cuando me pasó, y me tocó por sorteo.",
      "Ese día entré a quemar el incienso y no salí igual que como entré.",
      "Me dijeron que iba a tener un hijo siendo viejo, y pregunté cómo podía saber que era cierto.",
      "Por no creer me quedé mudo hasta el día que nació.",
      "Soy sacerdote, esposo de Elisabet y padre de Juan el Bautista." ] },
  { nombre: "Elisabet", mision: 1, cita: "Lucas 1:24-25, 41-45, 60",
    remate: "Cuando quisieron ponerle el nombre del padre, ella dijo: “No; se llamará Juan”.",
    pistas: [
      "Era anciana y todos daban por hecho que nunca iba a tener hijos.",
      "Recibí una visita que se quedó tres meses en mi casa.",
      "Cuando llegó esa visita, la criatura saltó en mi vientre.",
      "Mi marido estaba mudo y fui yo la que dijo cómo se iba a llamar el bebé.",
      "Soy la mamá de Juan el Bautista." ] },
  { nombre: "el ángel Gabriel", mision: 1, cita: "Lucas 1:19, 26-38",
    remate: "El mismo mensajero llevó los dos anuncios: el de Juan y el de Jesús.",
    pistas: [
      "Estoy en las dos historias, pero nunca soy el protagonista.",
      "Trabajo llevando mensajes, y digo mi nombre cuando me desconfían.",
      "Una vez dejé mudo al que no me creyó.",
      "Le dije a una joven que nada hay imposible para Dios.",
      "Soy el ángel que anunció el nacimiento de Juan y el de Jesús." ] },
  { nombre: "María", mision: 1, cita: "Lucas 1:26-38 · Lucas 2:19",
    remate: "Su respuesta fue: “He aquí la sierva del Señor; hágase conmigo conforme a tu palabra”.",
    pistas: [
      "Me hicieron un anuncio enorme y lo primero que hice fue preguntar cómo iba a ser posible.",
      "Viajé a lo de una parienta y me quedé como tres meses.",
      "Guardaba todas estas cosas y las meditaba en mi corazón.",
      "Me dijeron que le pusiera JESÚS.",
      "Soy la madre de Jesús." ] },
  { nombre: "José", mision: 2, cita: "Lucas 2:4-5 · Mateo 2:13-14",
    remate: "En la Biblia no dice una sola palabra suya: todo lo que sabemos de él es lo que hizo.",
    pistas: [
      "Tuve que viajar por un trámite del gobierno en el peor momento posible.",
      "No dije ni una palabra en toda la historia, pero me levanté de noche cada vez que me avisaron.",
      "Me mandaron a huir a Egipto y me fui esa misma noche.",
      "Subí a Belén porque era de la casa y familia de David.",
      "Soy el esposo de María." ] },
  { nombre: "los pastores", mision: 2, cita: "Lucas 2:8-20",
    remate: "Fueron los primeros en enterarse, y salieron corriendo a contarlo.",
    pistas: [
      "Estábamos trabajando de noche, a la intemperie, cuando nos avisaron.",
      "Nos dieron una señal para reconocerlo, y era una señal rarísima para un rey.",
      "Nos dio muchísimo miedo, y lo primero que nos dijeron fue que no temiéramos.",
      "Fuimos con prisa y lo encontramos acostado en un pesebre.",
      "Cuidábamos las ovejas cerca de Belén." ] },
  { nombre: "los magos del oriente", mision: 2, cita: "Mateo 2:1-12",
    remate: "La Biblia no dice cuántos eran ni que fueran reyes: dice que llevaron tres clases de regalos.",
    pistas: [
      "Veníamos de lejos siguiendo algo que vimos en el cielo.",
      "Antes de llegar preguntamos en el lugar equivocado, y eso trajo problemas.",
      "Entramos en una casa, no en un establo: el niño ya no era un recién nacido.",
      "Trajimos oro, incienso y mirra.",
      "Volvimos a nuestra tierra por otro camino para no pasar por lo de Herodes." ] },
  { nombre: "Herodes", mision: 2, cita: "Mateo 2:3-8, 16",
    remate: "Dijo que quería ir a adorarlo. Era mentira.",
    pistas: [
      "Cuando me llegó la noticia me turbé, y conmigo toda la ciudad.",
      "Junté a los que sabían de las Escrituras para que me averiguaran un dato.",
      "Dije que yo también quería ir a adorarlo.",
      "Cuando vi que me habían burlado, me enojé muchísimo.",
      "Soy el rey que mandó matar a los niños de Belén." ] },
  { nombre: "Juan el Bautista", mision: 3, cita: "Mateo 3:1-12 · Juan 1:19-34 · Juan 3:30",
    remate: "Dijo: “Es necesario que él crezca, pero que yo mengüe”.",
    pistas: [
      "Crecí en lugares desiertos y no volví hasta el día que me tocó aparecer.",
      "Andaba vestido de pelo de camello y comía langostas y miel silvestre.",
      "Cuando me preguntaron quién era, lo primero que dije fue quién NO era.",
      "Dije que no era digno ni de llevarle el calzado al que venía detrás de mí.",
      "Lo señalé y dije: He aquí el Cordero de Dios." ] },
  { nombre: "el Espíritu Santo", mision: 4, cita: "Mateo 3:16 · Juan 1:32-33 · Mateo 4:1",
    remate: "La señal que le habían dado a Juan era esa: sobre quien lo viera descender y permanecer, ése era.",
    pistas: [
      "Vine del cielo y me quedé.",
      "Era la señal convenida para reconocer a alguien.",
      "Después de eso lo llevé al desierto.",
      "Bajé en forma de paloma.",
      "Soy la tercera persona de la Trinidad." ] },
  { nombre: "la voz del cielo", mision: 4, cita: "Mateo 3:17",
    remate: "“Este es mi Hijo amado, en quien tengo complacencia.”",
    pistas: [
      "Se me escuchó una sola vez en toda esta historia, y no se me vio.",
      "Hablé justo cuando alguien salía del agua.",
      "Dije nueve palabras y con eso alcanzó.",
      "Hablé de un Hijo y dije que estaba muy contento con él.",
      "Soy la voz del Padre en el bautismo de Jesús." ] },
  { nombre: "Jesús", mision: 4, cita: "Mateo 3:13-17 · Lucas 2:7",
    remate: "Se hizo bautizar sin necesitarlo: “así conviene que cumplamos toda justicia”.",
    pistas: [
      "Nací en un viaje, lejos de casa, porque el emperador ordenó un censo.",
      "Mi primera cuna fue donde comen los animales.",
      "Viajé desde Galilea hasta el Jordán con un pedido que dejó al otro sin saber qué hacer.",
      "El que tenía que bautizarme decía que era al revés.",
      "Soy el Hijo de Dios." ] },

  /* ---- de toda la Biblia ---- */
  { nombre: "Adán", cita: "Génesis 2-3", origen: "biblia",
    remate: "Fue el primero en esconderse de Dios.",
    pistas: ["Fui el primero en tener un trabajo.", "Le puse el nombre a todos los animales.",
      "Cuando me preguntaron qué había hecho, eché la culpa.", "Comí lo único que tenía prohibido.",
      "Soy el primer hombre."] },
  { nombre: "Noé", cita: "Génesis 6-9", origen: "biblia",
    remate: "Dios puso el arco iris como señal de que no volvería a haber un diluvio así.",
    pistas: ["Trabajé años en algo que todos veían como una locura.",
      "Nunca había llovido así y yo igual seguí construyendo.",
      "Viajé con toda mi familia y con muchísima compañía animal.",
      "Solté una paloma para ver si ya se podía bajar.",
      "Soy el del arca y el diluvio."] },
  { nombre: "Abraham", cita: "Génesis 12, 22", origen: "biblia",
    remate: "Dios le prometió una descendencia como las estrellas del cielo.",
    pistas: ["Me mandaron a mudarme sin decirme adónde, y fui.",
      "Me prometieron algo que a mi edad era imposible.", "Tuve un hijo cuando ya era muy viejo.",
      "Subí a un monte con mi hijo y con la leña, y Dios frenó mi mano.",
      "Me llaman el padre de la fe."] },
  { nombre: "José, el hijo de Jacob", cita: "Génesis 37-45", origen: "biblia",
    remate: "Les dijo a sus hermanos: lo que pensasteis mal contra mí, Dios lo encaminó a bien.",
    pistas: ["Mis propios hermanos me tuvieron bronca por algo que ni siquiera hice.",
      "Terminé preso por algo que no hice.", "Me hice famoso por entender sueños.",
      "Mi papá me regaló una túnica de colores.",
      "Llegué a ser el segundo de Egipto y les salvé la vida a los que me vendieron."] },
  { nombre: "Moisés", cita: "Éxodo 3, 14", origen: "biblia",
    remate: "Dios le habló desde una zarza que ardía y no se consumía.",
    pistas: ["De bebé me salvaron escondiéndome en el agua.",
      "Cuando Dios me llamó le dije que buscara a otro porque yo hablaba mal.",
      "Discutí muchas veces con un rey que no quería soltar a mi pueblo.",
      "Levanté mi vara y el mar se abrió.", "Bajé del monte con los diez mandamientos."] },
  { nombre: "Josué", cita: "Josué 1, 6", origen: "biblia",
    remate: "“Esfuérzate y sé valiente”: se lo repitieron tres veces antes de empezar.",
    pistas: ["Me tocó reemplazar a alguien que nadie creía reemplazable.",
      "Fui uno de los dos que volvió diciendo que sí se podía.",
      "Mi estrategia de guerra fue caminar en círculos.",
      "Los muros se cayeron solos al séptimo día.", "Conquisté Jericó."] },
  { nombre: "Gedeón", cita: "Jueces 6-7", origen: "biblia",
    remate: "Dios le sacó soldados en vez de darle: con 300 alcanzaba para que quedara claro quién ganó.",
    pistas: ["Cuando me llamaron valiente yo estaba escondido trabajando.",
      "Pedí una señal, y después pedí otra por las dudas.",
      "Empecé con treinta y dos mil hombres y terminé con trescientos.",
      "Mi prueba fue un vellón de lana mojado y seco.",
      "Gané la batalla con trompetas, cántaros y antorchas."] },
  { nombre: "Sansón", cita: "Jueces 13-16", origen: "biblia",
    remate: "Su fuerza no estaba en el pelo: estaba en Dios, y el pelo era la señal de su promesa.",
    pistas: ["Mi secreto no era un músculo.", "Maté un león con las manos.",
      "Hablé de más por amor y me costó todo.", "Me cortaron el pelo mientras dormía.",
      "Derribé las columnas del templo de los filisteos."] },
  { nombre: "Rut", cita: "Rut 1-4", origen: "biblia",
    remate: "Terminó siendo bisabuela de David, y por eso está en la familia de Jesús.",
    pistas: ["No era de este pueblo y me quedé igual.",
      "Podía volver a mi tierra y elegí no hacerlo.",
      "Dije: adonde tú fueres, iré yo; tu pueblo será mi pueblo.",
      "Trabajé juntando espigas atrás de los segadores.",
      "Me casé con Booz."] },
  { nombre: "David", cita: "1 Samuel 16-17 · Salmos 23", origen: "biblia",
    remate: "Le dijo al gigante: tú vienes con espada, mas yo vengo en el nombre de Jehová.",
    pistas: ["Era el más chico de la casa y ni me llamaron cuando vinieron a buscar a alguien.",
      "Mi primer trabajo fue cuidar ovejas.", "Tocaba el arpa para calmar a un rey.",
      "Me ofrecieron una armadura y la dejé porque no sabía usarla.",
      "Tumbé a Goliat con una piedra."] },
  { nombre: "Salomón", cita: "1 Reyes 3", origen: "biblia",
    remate: "Dios le ofreció lo que quisiera y pidió un corazón entendido para juzgar al pueblo.",
    pistas: ["Me ofrecieron cualquier cosa y no pedí ni plata ni años de vida.",
      "Resolví un caso mandando a partir a un bebé al medio, y así se supo la verdad.",
      "Escribí un montón de proverbios.", "Construí el templo.",
      "Soy el hijo de David, el rey más sabio."] },
  { nombre: "Elías", cita: "1 Reyes 18-19", origen: "biblia",
    remate: "Después del fuego se deprimió y se quiso morir; Dios le mandó comida y le habló en un silbo apacible.",
    pistas: ["Le anuncié a un rey que no iba a llover, y no llovió por años.",
      "Me trajo la comida un pájaro.", "Desafié a cuatrocientos cincuenta profetas yo solo.",
      "Mojé el altar con agua tres veces antes de que cayera el fuego.",
      "Me fui al cielo en un carro de fuego."] },
  { nombre: "Daniel", cita: "Daniel 1, 6", origen: "biblia",
    remate: "Sabía que la ley estaba firmada y abrió la ventana igual, tres veces al día.",
    pistas: ["De chico me llevaron preso a un país que no era el mío.",
      "Me negué a comer lo que comían todos.",
      "Sacaron una ley con nombre y apellido para hacerme caer.",
      "Seguí orando con la ventana abierta aunque estaba prohibido.",
      "Pasé la noche en el foso de los leones y no me pasó nada."] },
  { nombre: "Jonás", cita: "Jonás 1-4", origen: "biblia",
    remate: "Se enojó porque Dios perdonó a la ciudad: él quería que la castigara.",
    pistas: ["Me mandaron a un lugar y compré pasaje para el lado contrario.",
      "Por mi culpa una tormenta casi hunde un barco lleno de gente.",
      "Dormí mientras todos los demás se morían de miedo.",
      "Estuve tres días adentro de un gran pez.",
      "Al final prediqué en Nínive y toda la ciudad se arrepintió."] },
  { nombre: "Pedro", cita: "Mateo 14 · Lucas 22 · Hechos 2", origen: "biblia",
    remate: "Negó a Jesús tres veces, y después fue el que predicó cuando nacieron tres mil creyentes en un día.",
    pistas: ["Hablaba antes de pensar, casi siempre.",
      "Dejé mi trabajo de un día para el otro por seguir a alguien.",
      "Caminé sobre el agua hasta que miré las olas.",
      "Le corté la oreja a un soldado.",
      "Lloré amargamente cuando cantó el gallo."] },
  { nombre: "Zaqueo", cita: "Lucas 19:1-10", origen: "biblia",
    remate: "Devolvió cuatro veces más de lo que había robado, sin que se lo pidieran.",
    pistas: ["Tenía plata y no tenía amigos.", "Mi trabajo era cobrarle a mi propia gente para los romanos.",
      "Era muy bajo y no veía nada entre la multitud.", "Me subí a un árbol para poder ver.",
      "Jesús me llamó por mi nombre y se invitó a comer a mi casa."] },
  { nombre: "Pablo", cita: "Hechos 9 · Filipenses 4:13", origen: "biblia",
    remate: "Escribió gran parte del Nuevo Testamento, y muchas cartas las escribió preso.",
    pistas: ["Empecé estando del lado exactamente contrario.",
      "Perseguía a los cristianos y tenía permiso firmado para hacerlo.",
      "Una luz me tiró al suelo en el camino y quedé ciego tres días.",
      "Canté himnos en la cárcel a medianoche y tembló todo.",
      "Escribí: todo lo puedo en Cristo que me fortalece."] }
];

/* ============================================================
   TABÚ — el que adivina se sienta de espaldas a la pantalla.
   Las prohibidas son las palabras que uno diría sin pensar; si la
   palabra es compuesta, sus propias partes van prohibidas.
   ============================================================ */
const tabu = [
  { palabra: "Pesebre", origen: "semestre", prohibidas: ["Jesús", "animales", "comida", "establo", "cuna"] },
  { palabra: "Pañales", origen: "semestre", prohibidas: ["bebé", "tela", "envolver", "señal", "pesebre"] },
  { palabra: "Censo", origen: "semestre", prohibidas: ["contar", "gente", "emperador", "Belén", "anotarse"] },
  { palabra: "Belén", origen: "semestre", prohibidas: ["nacer", "ciudad", "David", "Jesús", "pesebre"] },
  { palabra: "Incienso", origen: "semestre", prohibidas: ["quemar", "templo", "olor", "regalo", "magos"] },
  { palabra: "Tablilla", origen: "semestre", prohibidas: ["escribir", "Zacarías", "mudo", "nombre", "Juan"] },
  { palabra: "Ángel", origen: "semestre", prohibidas: ["Gabriel", "cielo", "mensaje", "alas", "anunciar"] },
  { palabra: "Estrella", origen: "semestre", prohibidas: ["magos", "oriente", "cielo", "brillar", "guiar"] },
  { palabra: "Mirra", origen: "semestre", prohibidas: ["oro", "incienso", "regalo", "magos", "perfume"] },
  { palabra: "Camello", origen: "semestre", prohibidas: ["Juan", "pelo", "ropa", "desierto", "joroba"] },
  { palabra: "Langostas", origen: "semestre", prohibidas: ["comer", "miel", "Juan", "desierto", "bicho"] },
  { palabra: "Jordán", origen: "semestre", prohibidas: ["río", "bautizar", "agua", "Juan", "Jesús"] },
  { palabra: "Paloma", origen: "semestre", prohibidas: ["Espíritu", "bajar", "cielo", "bautismo", "ave"] },
  { palabra: "Desierto", origen: "semestre", prohibidas: ["Juan", "arena", "seco", "tentación", "solo"] },
  { palabra: "Mudo", origen: "semestre", prohibidas: ["Zacarías", "hablar", "callado", "no creer", "tablilla"] },
  { palabra: "Cordero", origen: "semestre", prohibidas: ["Dios", "Juan", "oveja", "pecado", "Jesús"] },
  { palabra: "Nazaret", origen: "semestre", prohibidas: ["María", "pueblo", "Galilea", "vivir", "José"] },
  { palabra: "Bautismo", origen: "semestre", prohibidas: ["agua", "Juan", "río", "Jesús", "sumergir"] },

  { palabra: "Arca", origen: "biblia", prohibidas: ["Noé", "barco", "diluvio", "animales", "madera"] },
  { palabra: "Arco iris", origen: "biblia", prohibidas: ["colores", "lluvia", "cielo", "Noé", "promesa"] },
  { palabra: "Honda", origen: "biblia", prohibidas: ["David", "Goliat", "piedra", "tirar", "gigante"] },
  { palabra: "Gigante", origen: "biblia", prohibidas: ["Goliat", "grande", "alto", "David", "filisteo"] },
  { palabra: "León", origen: "biblia", prohibidas: ["Daniel", "foso", "rugir", "animal", "Sansón"] },
  { palabra: "Ballena", origen: "biblia", prohibidas: ["Jonás", "pez", "tragar", "mar", "grande"] },
  { palabra: "Maná", origen: "biblia", prohibidas: ["comer", "desierto", "cielo", "pan", "Moisés"] },
  { palabra: "Zarza", origen: "biblia", prohibidas: ["Moisés", "fuego", "arder", "planta", "hablar"] },
  { palabra: "Vara", origen: "biblia", prohibidas: ["Moisés", "palo", "mar", "serpiente", "levantar"] },
  { palabra: "Trompeta", origen: "biblia", prohibidas: ["Jericó", "sonar", "muros", "Josué", "instrumento"] },
  { palabra: "Templo", origen: "biblia", prohibidas: ["Salomón", "casa", "Dios", "construir", "orar"] },
  { palabra: "Túnica", origen: "biblia", prohibidas: ["José", "colores", "ropa", "hermanos", "regalo"] },
  { palabra: "Gallo", origen: "biblia", prohibidas: ["Pedro", "cantar", "negar", "tres veces", "ave"] },
  { palabra: "Arpa", origen: "biblia", prohibidas: ["David", "tocar", "música", "Saúl", "cuerdas"] },
  { palabra: "Oración", origen: "biblia", prohibidas: ["orar", "hablar", "Dios", "rezar", "pedir"] },
  { palabra: "Discípulo", origen: "biblia", prohibidas: ["Jesús", "seguir", "doce", "aprender", "apóstol"] },
  { palabra: "Parábola", origen: "biblia", prohibidas: ["Jesús", "cuento", "enseñar", "historia", "ejemplo"] },
  { palabra: "Sembrador", origen: "biblia", prohibidas: ["semilla", "campo", "parábola", "tierra", "plantar"] },
  { palabra: "Pastor", origen: "biblia", prohibidas: ["oveja", "cuidar", "Salmo 23", "rebaño", "David"] },
  { palabra: "Milagro", origen: "biblia", prohibidas: ["Jesús", "imposible", "sanar", "poder", "asombro"] }
];

const salida = {
  titulo: "Más juegos para proyectar",
  version: "Reina-Valera 1960",
  _comentario: "Contenido de los tres juegos nuevos de proyectar.html. Los versículos con origen 'semestre' se copiaron de lecciones/*.json con el script .claude/armar-mas-juegos.js: si se corrige una lección, hay que volver a correrlo.",
  personajes: personajes.map(p => ({ origen: "semestre", ...p })),
  tabu,
  versiculos: [...delSemestre, ...generales]
};

const destino = path.join(RAIZ, "juegos", "mas-juegos.json");
fs.writeFileSync(destino, JSON.stringify(salida, null, 1) + "\n", "utf8");
console.log(destino + ": " +
  salida.personajes.length + " personajes, " +
  salida.tabu.length + " palabras, " +
  salida.versiculos.length + " versículos (" +
  delSemestre.length + " del semestre + " + generales.length + " de toda la Biblia)");
