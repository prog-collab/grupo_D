/* =====================================================================
   avisar-respuesta

   Vacía la cola de avisos a los chicos: "tu maestro te contestó".

   La llaman dos: el disparador de escuela.consultas, cuando el maestro
   contesta dentro del horario, y pg_cron cada 5 minutos, que es el que
   despierta a los que quedaron esperando a las 9 de la mañana.

   No decide horarios: eso ya lo resolvió la base al encolar. Acá se
   manda lo que esté vencido y listo. Cada aviso se marca por separado:
   si uno falla, los otros salen igual y ese vuelve a intentarse en la
   corrida siguiente.
   ===================================================================== */
import { enviar } from "./push.js";

const SUPA_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICIO = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

type Telefono = { endpoint: string; p256dh: string; auth: string };
type Aviso = {
  id: number; titulo: string; cuerpo: string; donde: string;
  url: string; tag: string; telefonos: Telefono[];
};

async function rpc(fn: string, params: Record<string, unknown>) {
  const r = await fetch(SUPA_URL + "/rest/v1/rpc/" + fn, {
    method: "POST",
    headers: {
      "apikey": SERVICIO,
      "Authorization": "Bearer " + SERVICIO,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(params)
  });
  if (!r.ok) throw new Error("rpc " + fn + ": HTTP " + r.status + " " + await r.text());
  return r.json();
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Solo POST", { status: 405 });

  const secreto = req.headers.get("x-aviso-secreto") || "";
  if (!secreto) return new Response("No autorizado", { status: 403 });

  const datos = await rpc("ed_push_respuestas", { p_secreto: secreto });
  if (!datos.ok) {
    const noAutorizado = String(datos.error || "").startsWith("No autorizado");
    return new Response(datos.error || "No se pudo", { status: noAutorizado ? 403 : 400 });
  }
  if (!datos.vapid) return new Response("Falta la clave VAPID", { status: 500 });

  const vapid = {
    jwkPrivada: datos.vapid,
    publica: publicaDesde(datos.vapid),
    contacto: datos.contacto
  };

  let mandados = 0;
  for (const aviso of datos.avisos as Aviso[]) {
    const mensaje = JSON.stringify({
      titulo: aviso.titulo, cuerpo: aviso.cuerpo, donde: aviso.donde,
      url: aviso.url, tag: aviso.tag
    });

    /* Sin teléfonos no hay nada que mandar, pero igual lo doy por hecho:
       si no, el chico que apagó los avisos deja la cola llena para
       siempre. */
    let algunoAndando = aviso.telefonos.length === 0;

    for (const sub of aviso.telefonos) {
      try {
        const r = await enviar(sub, mensaje, vapid);
        if (!r.muerta) algunoAndando = true;
        else await rpc("ed_push_alumno_borrar", { p_secreto: secreto, p_endpoint: sub.endpoint });
        mandados++;
      } catch (e) {
        console.error("no pude avisar a", sub.endpoint.slice(0, 40), e);
      }
    }

    if (algunoAndando) {
      await rpc("ed_push_respuesta_lista", { p_secreto: secreto, p_id: aviso.id });
    }
  }

  return new Response(JSON.stringify({
    ok: true, avisos: (datos.avisos as Aviso[]).length, envios: mandados
  }), { headers: { "Content-Type": "application/json" } });
});

/* La pública sale de la privada: son las mismas coordenadas x e y. */
function publicaDesde(jwk: { x: string; y: string }) {
  const b64u = (s: string) => {
    const base = s.replace(/-/g, "+").replace(/_/g, "/");
    const bin = atob(base + "=".repeat((4 - (base.length % 4)) % 4));
    return Uint8Array.from(bin, c => c.charCodeAt(0));
  };
  const x = b64u(jwk.x), y = b64u(jwk.y);
  const raw = new Uint8Array(65);
  raw[0] = 4;
  raw.set(x, 1);
  raw.set(y, 33);
  let bin = "";
  for (const b of raw) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
