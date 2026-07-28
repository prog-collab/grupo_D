/* =====================================================================
   avisar-consulta

   La llama el disparador de escuela.consultas cada vez que un chico
   pregunta. Busca a qué teléfonos hay que avisarle y les manda la
   notificación cifrada.

   No pide JWT: se identifica con el secreto que viaja en la cabecera
   x-aviso-secreto, que el disparador saca de vault. Sin ese secreto no
   hace nada.

   Si un envío vuelve 404 o 410, ese teléfono ya no existe (desinstaló
   la app o apagó los avisos) y borramos la suscripción: si no, se
   juntan endpoints muertos para siempre.
   ===================================================================== */
import { enviar } from "./push.js";

const SUPA_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICIO = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

/* Comparación que no delata el secreto por el tiempo que tarda. */
function igual(a: string, b: string) {
  if (a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Solo POST", { status: 405 });

  let consulta: number;
  try {
    consulta = Number((await req.json()).consulta);
    if (!Number.isFinite(consulta)) throw new Error("consulta invalida");
  } catch {
    return new Response("Cuerpo invalido", { status: 400 });
  }

  const datos = await rpc("ed_push_aviso", { p_consulta: consulta });
  if (!datos.ok) return new Response(datos.error || "No se pudo", { status: 404 });

  const traido = req.headers.get("x-aviso-secreto") || "";
  if (!datos.secreto || !igual(traido, datos.secreto)) {
    return new Response("No autorizado", { status: 403 });
  }
  if (!datos.vapid) return new Response("Falta la clave VAPID", { status: 500 });

  const vapid = {
    jwkPrivada: datos.vapid,
    publica: datos.vapid.publica ?? publicaDesde(datos.vapid),
    contacto: datos.contacto
  };

  const mensaje = JSON.stringify({
    titulo: datos.titulo,
    cuerpo: datos.cuerpo,
    donde: datos.donde,
    url: "panel.html?pregunta=" + datos.consulta,
    tag: "consulta-" + datos.consulta
  });

  const resultados = await Promise.all(
    (datos.telefonos as { endpoint: string; p256dh: string; auth: string }[]).map(async (sub) => {
      try {
        const r = await enviar(sub, mensaje, vapid);
        await rpc("ed_push_resultado", { p_endpoint: sub.endpoint, p_estado: r.estado });
        if (r.muerta) await rpc("ed_push_borrar", { p_endpoint: sub.endpoint });
        return r.estado;
      } catch (e) {
        console.error("no pude avisar a", sub.endpoint.slice(0, 40), e);
        return 0;
      }
    })
  );

  return new Response(JSON.stringify({ ok: true, avisados: resultados }), {
    headers: { "Content-Type": "application/json" }
  });
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
