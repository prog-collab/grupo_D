/*
 * Validador de lecciones.
 *
 * Regla principal: en las preguntas del quiz, toda opción de "evidencia" que sea
 * una cita bíblica tiene que ser un versículo que el alumno YA vio en el
 * expediente (estaciones de tipo "pasaje"). Si le ofrecemos una cita que nunca
 * apareció, la pregunta no se puede contestar leyendo: sólo se adivina.
 *
 * Uso:  node validar-lecciones.js
 * Sale con código 1 si encuentra algún problema.
 */

const fs = require("fs");
const path = require("path");

const DIR = path.join(__dirname, "lecciones");
const ES_CITA = /^[1-3]?\s?[A-ZÁÉÍÓÚ][a-záéíóúñ]+\.?\s+\d+:\d+/;

let problemas = 0;
const aviso = (msg) => { problemas++; console.log("  ✗ " + msg); };

for (const archivo of fs.readdirSync(DIR).filter(f => f.endsWith(".json")).sort()) {
  const leccion = JSON.parse(fs.readFileSync(path.join(DIR, archivo), "utf8"));
  console.log("\n" + archivo + " — " + leccion.titulo);

  // Todo lo que el alumno llega a ver antes de las preguntas.
  const visibles = new Set();
  for (const est of leccion.estaciones || []) {
    if (est.tipo !== "pasaje") continue;
    for (const bloque of est.bloques || []) {
      for (const v of bloque.versiculos || []) visibles.add(v.ref);
    }
  }

  for (const est of leccion.estaciones || []) {
    if (est.tipo !== "quiz") continue;
    (est.preguntas || []).forEach((p, i) => {
      const ev = p.evidencia;
      if (!ev) return;
      const donde = est.id + " · pregunta " + (i + 1);

      ev.opciones.forEach((opcion, j) => {
        if (!ES_CITA.test(opcion)) return;      // evidencia de hecho, no de cita
        if (visibles.has(opcion)) return;
        const cual = j === ev.correcta ? "la respuesta correcta" : "un distractor";
        aviso(donde + ": " + cual + " es «" + opcion + "», que no está en el expediente.");
      });

      if (ev.correcta == null || !ev.opciones[ev.correcta]) {
        aviso(donde + ": el índice de la respuesta correcta no apunta a ninguna opción.");
      }
    });
  }

  console.log("  versículos en el expediente: " + visibles.size);
}

if (problemas) {
  console.log("\n" + problemas + " problema(s). Agregá el versículo al expediente o cambiá la opción.");
  process.exit(1);
}
console.log("\nTodo en orden: cada cita ofrecida en el quiz se puede leer antes.");
