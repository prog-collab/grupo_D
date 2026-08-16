/* Service worker del Explorador Bíblico.
 *
 * La idea: que la app abra siempre, aunque el chico esté sin datos o con
 * mala señal en la casa. Pero que el contenido de las lecciones se
 * actualice solo cuando corregimos algo, sin tener que reinstalar nada.
 *
 * Por eso: red primero para el HTML y las lecciones (si hay internet, ve
 * lo último), y caché primero para íconos y manifiesto, que no cambian.
 *
 * Al publicar una versión nueva conviene subir el número de CACHE: eso
 * borra la anterior y evita que queden mezclados archivos viejos y nuevos.
 */
const CACHE = "explorador-v10";

const BASICOS = [
  "./",
  "index.html",
  "panel.html",
  "proyectar.html",
  "juegos/camino-con-jesus.json",
  "juegos/mas-juegos.json",
  "juegos/juegos-renovados.json",
  "manifest.webmanifest",
  "iconos/icono-192.png",
  "iconos/icono-512.png",
  "iconos/icono-maskable-512.png",
  "apple-touch-icon.png",
  "lecciones/repaso-1-anuncios.json",
  "lecciones/repaso-2-nacimiento.json",
  "lecciones/repaso-3-juan.json",
  "lecciones/repaso-4-bautismo.json",
  "lecciones/repaso-5-final.json"
];

async function precargar() {
  const c = await caches.open(CACHE);
  /* Uno por uno: si mañana falta un archivo de la lista, no quiero que
     falle la instalación entera y la app se quede sin service worker. */
  await Promise.all(BASICOS.map(u => c.add(u).catch(() => {})));
}

self.addEventListener("install", ev => {
  ev.waitUntil(precargar().then(() => self.skipWaiting()));
});

self.addEventListener("activate", ev => {
  ev.waitUntil((async () => {
    const nombres = await caches.keys();
    await Promise.all(nombres.filter(n => n !== CACHE).map(n => caches.delete(n)));
    /* Android borra cachés cuando el teléfono se queda sin espacio. Si eso
       pasó, el service worker sigue instalado pero sin nada guardado: la app
       dejaría de abrir sin internet justo cuando más se necesita. */
    const c = await caches.open(CACHE);
    if ((await c.keys()).length === 0) await precargar();
    await self.clients.claim();
  })());
});

const esContenido = url =>
  url.pathname.endsWith(".html") ||
  url.pathname.endsWith(".json") ||
  url.pathname.endsWith(".webmanifest") ||
  url.pathname.endsWith("/");

self.addEventListener("fetch", ev => {
  const req = ev.request;
  if (req.method !== "GET") return;                       // Supabase va por POST
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;        // sólo lo nuestro

  /* Navegaciones y contenido: primero la red. El ?leccion=… no cambia el
     archivo servido, así que guardo y busco por la ruta sin la consulta. */
  if (req.mode === "navigate" || esContenido(url)) {
    const clave = url.pathname + (url.pathname.endsWith("/") ? "" : "");
    ev.respondWith((async () => {
      try {
        const r = await fetch(req);
        if (r && r.ok) (await caches.open(CACHE)).put(clave, r.clone());
        return r;
      } catch {
        const c = await caches.open(CACHE);
        return (await c.match(clave)) ||
               (await c.match("index.html")) ||
               new Response("Sin conexión", { status: 503, headers: { "Content-Type": "text/plain" } });
      }
    })());
    return;
  }

  /* Íconos y demás: caché primero, y de paso lo refresco por atrás. */
  ev.respondWith((async () => {
    const c = await caches.open(CACHE);
    const guardado = await c.match(req);
    const red = fetch(req).then(r => { if (r && r.ok) c.put(req, r.clone()); return r; }).catch(() => null);
    return guardado || (await red) || new Response("", { status: 504 });
  })());
});

/* =====================================================================
   Avisos al maestro.

   Cuando un chico pregunta, el servidor le manda esto al navegador del
   maestro aunque tenga la app cerrada. Al tocar la notificación se abre
   el panel en esa pregunta: si ya lo tenía abierto en otra pestaña, uso
   esa en vez de abrir una nueva.
   ===================================================================== */
self.addEventListener("push", ev => {
  let d = {};
  try { d = ev.data ? ev.data.json() : {}; } catch { d = {}; }

  const cuerpo = [d.cuerpo, d.donde && "— " + d.donde].filter(Boolean).join("\n");
  ev.waitUntil(self.registration.showNotification(d.titulo || "Una pregunta nueva", {
    body: cuerpo || "Un chico te preguntó algo en la app.",
    icon: "iconos/icono-192.png",
    badge: "iconos/icono-192.png",
    /* Con el mismo tag, dos avisos de la misma pregunta no se apilan. */
    tag: d.tag || "consulta",
    data: { url: d.url || "panel.html" },
    lang: "es-AR"
  }));
});

self.addEventListener("notificationclick", ev => {
  ev.notification.close();
  const destino = new URL((ev.notification.data && ev.notification.data.url) || "panel.html",
                          self.registration.scope);
  ev.waitUntil((async () => {
    const abiertas = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    /* Reuso la ventana que ya está en ese archivo — el panel para el
       maestro, la app para el chico — y no la del otro: si el maestro
       tiene las dos abiertas, un aviso de la app no le tiene que pisar
       el panel donde está contestando. */
    for (const c of abiertas) {
      if (new URL(c.url).pathname === destino.pathname) {
        await c.focus();
        if ("navigate" in c) await c.navigate(destino.href).catch(() => {});
        return;
      }
    }
    await self.clients.openWindow(destino.href);
  })());
});
