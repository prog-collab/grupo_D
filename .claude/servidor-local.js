// Servidor estático mínimo, sólo para probar la app en local.
// No forma parte de lo que se publica en GitHub Pages.
const http = require("http");
const fs = require("fs");
const path = require("path");

const RAIZ = path.resolve(__dirname, "..");
const PUERTO = 8899;
const TIPOS = { ".html": "text/html; charset=utf-8", ".json": "application/json; charset=utf-8",
                ".js": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8",
                ".png": "image/png", ".svg": "image/svg+xml",
                ".webmanifest": "application/manifest+json; charset=utf-8" };

http.createServer((req, res) => {
  const rel = decodeURIComponent(req.url.split("?")[0]);
  const archivo = path.join(RAIZ, rel === "/" ? "index.html" : rel);
  if (!archivo.startsWith(RAIZ)) { res.writeHead(403).end("no"); return; }
  fs.readFile(archivo, (err, data) => {
    if (err) { res.writeHead(404, { "Content-Type": "text/plain" }).end("404"); return; }
    res.writeHead(200, { "Content-Type": TIPOS[path.extname(archivo)] || "application/octet-stream" });
    res.end(data);
  });
}).listen(PUERTO, () => console.log("Sirviendo " + RAIZ + " en http://localhost:" + PUERTO));
