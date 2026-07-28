/* =====================================================================
   Web Push a mano.

   Mandarle una notificación al teléfono del maestro es, por debajo, un
   POST al servidor del navegador (Google, Mozilla, Apple) con el texto
   cifrado: ellos hacen de cartero y no pueden leer lo que llevan. El
   cifrado está en el RFC 8291 y la firma que nos identifica, en el 8292.

   Está escrito con Web Crypto, que viene tanto en Deno (donde corre
   esto) como en Node (donde lo probamos contra el ejemplo del RFC).
   Sin dependencias: una librería más es una cosa más que se rompe sola
   dentro de tres meses.
   ===================================================================== */

const utf8 = new TextEncoder();

export function b64uADatos(s) {
  const base = s.replace(/-/g, "+").replace(/_/g, "/");
  const bin = atob(base + "=".repeat((4 - (base.length % 4)) % 4));
  return Uint8Array.from(bin, c => c.charCodeAt(0));
}

export function datosAB64u(b) {
  let bin = "";
  for (const x of new Uint8Array(b)) bin += String.fromCharCode(x);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function pegar(...partes) {
  const total = partes.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(total);
  let i = 0;
  for (const p of partes) { out.set(p, i); i += p.length; }
  return out;
}

async function hkdf(salt, ikm, info, largo) {
  const base = await crypto.subtle.importKey("raw", ikm, "HKDF", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "HKDF", hash: "SHA-256", salt, info }, base, largo * 8);
  return new Uint8Array(bits);
}

/* Clave pública del navegador (65 bytes, punto sin comprimir) -> clave importable. */
function importarPublicaECDH(raw) {
  return crypto.subtle.importKey("raw", raw, { name: "ECDH", namedCurve: "P-256" }, true, []);
}

/* ---------------------------------------------------------------------
   Cifrado del cuerpo (RFC 8291, esquema aes128gcm del RFC 8188).
   El salt y el par efímero se pueden pasar desde afuera: así el test
   puede reproducir el ejemplo del RFC, que trae los suyos fijos.
   --------------------------------------------------------------------- */
export async function cifrar(texto, p256dhB64u, authB64u, opciones = {}) {
  const uaPublicaRaw = b64uADatos(p256dhB64u);
  const authSecret   = b64uADatos(authB64u);
  const salt = opciones.salt || crypto.getRandomValues(new Uint8Array(16));

  const efimero = opciones.efimero || await crypto.subtle.generateKey(
    { name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"]);
  const asPublicaRaw = new Uint8Array(await crypto.subtle.exportKey("raw", efimero.publicKey));

  const compartido = new Uint8Array(await crypto.subtle.deriveBits(
    { name: "ECDH", public: await importarPublicaECDH(uaPublicaRaw) }, efimero.privateKey, 256));

  const infoClave = pegar(utf8.encode("WebPush: info"), new Uint8Array([0]), uaPublicaRaw, asPublicaRaw);
  const ikm   = await hkdf(authSecret, compartido, infoClave, 32);
  const cek   = await hkdf(salt, ikm, pegar(utf8.encode("Content-Encoding: aes128gcm"), new Uint8Array([0])), 16);
  const nonce = await hkdf(salt, ikm, pegar(utf8.encode("Content-Encoding: nonce"), new Uint8Array([0])), 12);

  const clave = await crypto.subtle.importKey("raw", cek, "AES-GCM", false, ["encrypt"]);
  /* El 0x02 marca que este es el último (y único) bloque. */
  const plano = pegar(utf8.encode(texto), new Uint8Array([2]));
  const cifrado = new Uint8Array(await crypto.subtle.encrypt(
    { name: "AES-GCM", iv: nonce, tagLength: 128 }, clave, plano));

  /* Cabecera: salt(16) + tamaño de bloque(4) + largo de la clave(1) + clave(65). */
  const cab = new Uint8Array(21);
  cab.set(salt, 0);
  new DataView(cab.buffer).setUint32(16, 4096);
  cab[20] = asPublicaRaw.length;
  return pegar(cab, asPublicaRaw, cifrado);
}

/* ---------------------------------------------------------------------
   VAPID (RFC 8292): un JWT firmado que le dice al cartero quiénes
   somos. Sin esto, Google rechaza el envío.
   --------------------------------------------------------------------- */
export async function cabeceraVapid(endpoint, jwkPrivada, publicaB64u, contacto, ahora = Date.now()) {
  const clave = await crypto.subtle.importKey(
    "jwk", { ...jwkPrivada, key_ops: ["sign"], ext: true },
    { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);

  const cabeza = datosAB64u(utf8.encode(JSON.stringify({ typ: "JWT", alg: "ES256" })));
  const cuerpo = datosAB64u(utf8.encode(JSON.stringify({
    aud: new URL(endpoint).origin,
    exp: Math.floor(ahora / 1000) + 12 * 60 * 60,
    sub: contacto
  })));
  const firma = new Uint8Array(await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, clave, utf8.encode(cabeza + "." + cuerpo)));

  return "vapid t=" + cabeza + "." + cuerpo + "." + datosAB64u(firma) + ", k=" + publicaB64u;
}

/* ---------------------------------------------------------------------
   Un envío. Devuelve el estado para que quien llama decida si borra la
   suscripción: 404 y 410 significan que ese teléfono ya no está.
   --------------------------------------------------------------------- */
export async function enviar(sub, texto, vapid, ttl = 86400) {
  const cuerpo = await cifrar(texto, sub.p256dh, sub.auth);
  const r = await fetch(sub.endpoint, {
    method: "POST",
    headers: {
      "Authorization": await cabeceraVapid(sub.endpoint, vapid.jwkPrivada, vapid.publica, vapid.contacto),
      "Content-Encoding": "aes128gcm",
      "Content-Type": "application/octet-stream",
      "TTL": String(ttl),
      "Urgency": "high"
    },
    body: cuerpo
  });
  return { estado: r.status, muerta: r.status === 404 || r.status === 410 };
}
