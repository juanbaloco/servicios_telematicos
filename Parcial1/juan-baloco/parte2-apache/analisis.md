# Análisis crítico — Compresión en Apache

**Parcial Servicios Telemáticos · Universidad Autónoma de Occidente**
Servidor: Apache/2.4.52 (Ubuntu 22.04) · VM `web` 192.168.50.10 · Dominio `parcial.empresa.local`
Mediciones: 72 combinaciones (12 recursos × 6 configuraciones), promedio de 3 corridas por medición.

---

## Tabla comparativa — `lorem.txt` (recurso principal)

**Recurso evaluado:** `lorem.txt` · **Tamaño original:** 2.043.894 B (1,95 MB)

| Algoritmo / nivel | Tamaño | Ratio | Ahorro % | Tiempo |
|---|---|---|---|---|
| Sin comprimir (base) | 2.043.894 B | 1,0000 | 0,00 % | 0,0023 s |
| gzip nivel 1 | 46.991 B | 0,0229 | 97,71 % | 0,0119 s |
| gzip nivel 6 | 44.468 B | 0,0217 | 97,83 % | 0,0181 s |
| gzip nivel 9 | 43.598 B | 0,0213 | 97,87 % | 0,0197 s |
| brotli calidad 5 | 20.535 B | 0,0100 | 99,00 % | 0,0262 s |
| brotli calidad 11 | 19.843 B | 0,0097 | 99,03 % | 7,0532 s |

### Resumen por tipo de archivo (mejor gzip vs. mejor brotli)

| Recurso | Original | gzip 9 | brotli (mejor) | Mejora brotli |
|---|---|---|---|---|
| `lorem.txt` | 2.043.894 | 43.598 | 19.843 | **2,20×** |
| `datos.json` | 344.696 | 32.243 | 11.626 | **2,77×** |
| `index.html` | 459.909 | 17.351 | 7.258 | **2,39×** |
| `estilos.css` | 226.893 | 5.704 | 2.459 | **2,32×** |
| `feed.xml` | 205.839 | 11.351 | 5.062 | **2,24×** |
| `app.js` | 322.786 | 14.294 | 6.491 | **2,20×** |
| `grafico.svg` | 98.591 | 7.247 | 5.712 | **1,27×** |
| `foto.jpg` | 500.000 | 500.000 | 500.000 | — (excluido) |
| `imagen.png` | 300.000 | 300.000 | 300.000 | — (excluido) |
| `clip.mp4` | 800.000 | 800.000 | 800.000 | — (excluido) |
| `paquete.zip` | 644.863 | 644.863 | 644.863 | — (excluido) |

---

## 7. Brotli vs gzip

Sobre contenido de texto, Brotli mejora el ratio de gzip por un factor consistente de **2,2× a 2,8×**. El mejor caso es `datos.json` (32.243 B con gzip 9 contra 11.626 B con brotli 5: **2,77× menos bytes**), y el peor caso entre los archivos de texto es `app.js` con 2,20×.

La diferencia es **significativa en contenido con estructura repetitiva de alto nivel**: JSON con claves que se repiten en cada registro, HTML con la misma etiqueta `<div class="item">` miles de veces, texto natural con vocabulario acotado. Ahí Brotli explota dos ventajas sobre DEFLATE: una ventana deslizante de hasta 16 MB (`BrotliCompressionWindow 22` = 4 MB en nuestra configuración) frente a los 32 KB fijos de gzip, y un diccionario estático precargado de ~120 KB con fragmentos frecuentes de HTML, CSS y texto en varios idiomas.

La diferencia es **marginal en SVG** (1,27×, el único caso por debajo de 2×). La explicación está en la naturaleza del archivo: nuestro `grafico.svg` contiene 1.500 elementos `<circle>` con coordenadas aleatorias. Los atributos se repiten, pero los valores numéricos son entropía pura; ni la ventana grande ni el diccionario ayudan contra datos aleatorios.

Un hallazgo lateral relevante: al comparar `estilos.css` (226.893 B) con `estilos.min.css` (196.893 B), la minificación ahorra 13,2 % en disco, pero tras comprimir con gzip 9 la diferencia cae a **0,7 %** (5.704 B vs 5.664 B). El compresor ya elimina la redundancia de espacios y saltos de línea que la minificación quita manualmente. Minificar sigue valiendo la pena por el tiempo de parseo del navegador, no por el ancho de banda.

---

## 8. Niveles de compresión y punto de rendimientos decrecientes

### gzip: 1 → 6 → 9

Con `lorem.txt`:

| Transición | Ganancia en tamaño | Costo en tiempo |
|---|---|---|
| 1 → 6 | −5,4 % (46.991 → 44.468 B) | +52 % (0,0119 → 0,0181 s) |
| 6 → 9 | −2,0 % (44.468 → 43.598 B) | +9 % (0,0181 → 0,0197 s) |
| 1 → 9 total | −7,2 % | +66 % |

**El punto de rendimientos decrecientes de gzip está en el nivel 6.** Pasar de 1 a 6 cuesta la mitad más de CPU y devuelve 5,4 % de tamaño; pasar de 6 a 9 devuelve apenas 2 % más. Que el nivel 6 sea el valor por defecto de Apache no es casualidad: es el punto donde la curva se aplana.

En archivos pequeños la diferencia entre niveles es despreciable o incluso negativa. En `index.html`, gzip 1 produce 17.236 B y gzip 6 produce 17.612 B — el nivel más bajo comprimió **mejor**. Con contenido muy repetitivo, las heurísticas de búsqueda exhaustiva de los niveles altos pueden elegir peor que la estrategia rápida.

### brotli: 5 → 11

Aquí la conclusión es mucho más categórica:

| Recurso | brotli 5 | brotli 11 | Δ tamaño | tiempo 5 | tiempo 11 | Factor |
|---|---|---|---|---|---|---|
| `lorem.txt` | 20.535 B | 19.843 B | −3,4 % | 0,0262 s | 7,0532 s | **269×** |
| `index.html` | 7.258 B | 7.769 B | **+7,0 %** | 0,0059 s | 1,6409 s | 277× |
| `app.js` | 6.491 B | 6.721 B | **+3,5 %** | 0,0044 s | 0,7365 s | 166× |
| `datos.json` | 11.626 B | 12.577 B | **+8,2 %** | 0,0061 s | 0,6399 s | 105× |
| `grafico.svg` | 7.592 B | 5.712 B | −24,8 % | 0,0031 s | 0,1745 s | 56× |
| `estilos.css` | 2.779 B | 2.459 B | −11,5 % | 0,0034 s | 0,6655 s | 196× |

**El costo adicional de brotli 11 no se justifica en compresión al vuelo bajo ninguna lectura de estos datos.** En el mejor caso (`grafico.svg`) gana 24,8 % de tamaño a cambio de 56× más tiempo. En el caso más grande (`lorem.txt`) gana 3,4 % a cambio de **269× más tiempo** — 7 segundos para servir un archivo.

Más aún: en tres de siete recursos de texto, **brotli 11 produjo un archivo más grande que brotli 5**. Esto es contraintuitivo pero explicable: a partir de la calidad 10, Brotli cambia de algoritmo interno y usa un modelo de contexto más agresivo, optimizado para contenido heterogéneo. Nuestros archivos son sintéticos y extremadamente repetitivos, un caso donde el modelo simple de la calidad 5 acierta más. En contenido real la calidad 11 suele ganar, pero por márgenes pequeños que no cambian la conclusión de fondo.

**Punto de rendimientos decrecientes de Brotli: calidad 5.**

---

## 9. Tipos de archivo ya comprimidos

Los cuatro binarios (`foto.jpg`, `imagen.png`, `clip.mp4`, `paquete.zip`) devolvieron **ratio 1,0000 y ahorro 0 % en las seis configuraciones**, con `Content-Encoding` ausente en la respuesta. Esto se debe a la regla de exclusión configurada:

```apache
SetEnvIfNoCase Request_URI \.(?:gif|jpe?g|png|webp|mp4|avi|zip|gz|pdf)$ \
    no-gzip dont-vary
```

La justificación es teórica antes que empírica. JPEG, PNG, MP4 y ZIP ya aplican compresión internamente (DCT con cuantización, DEFLATE, códecs con predicción temporal, DEFLATE respectivamente). Un archivo bien comprimido tiene, por definición, **entropía cercana al máximo**: sus bytes se distribuyen de forma casi uniforme y no quedan patrones repetidos que LZ77 pueda referenciar ni sesgos de frecuencia que Huffman pueda explotar.

Comprimir esos datos no solo no reduce nada, sino que **añade bytes**: el encabezado gzip (10 bytes), el trailer con CRC32 y longitud (8 bytes), y los bloques "stored" que DEFLATE emite cuando detecta que comprimir sale más caro que copiar. El resultado es un archivo ligeramente mayor que el original, más el ciclo de CPU gastado para llegar a ese resultado peor.

Nuestros binarios se generaron con `/dev/urandom`, es decir, entropía máxima real. Esto los convierte en el caso límite perfecto: si se les quitara la exclusión, el crecimiento sería medible y sistemático. La verificación en Wireshark lo confirma desde el lado de la red: la respuesta de `foto.jpg` viaja sin `Content-Encoding` y con `Content-Length: 500000`, idéntico al tamaño en disco.

---

## 10. Impacto en CPU y ancho de banda

El equilibrio depende del recurso escaso. En nuestro entorno de laboratorio la red es virtual y prácticamente infinita, por lo que el CPU domina; en producción sobre enlaces reales la relación se invierte para la mayoría de sitios.

**Ahorro de ancho de banda.** El conjunto completo de recursos de texto suma 3.702.598 B sin comprimir. Con gzip 6 baja a 129.170 B (**96,5 % de ahorro**) y con brotli 5 a 56.323 B (**98,5 %**). Sobre un enlace de 10 Mbps, servir el conjunto sin comprimir toma ~3 s; con brotli 5, ~45 ms.

**Costo de CPU.** Los tiempos medidos incluyen la compresión completa en cada petición porque no hay caché de variantes. Para `lorem.txt`:

- gzip 6: 18,1 ms → un núcleo puede servir ~55 peticiones/s de ese archivo
- brotli 5: 26,2 ms → ~38 peticiones/s
- brotli 11: 7.053 ms → **0,14 peticiones/s**

**Bajo concurrencia alta el escenario cambia cualitativamente, no solo cuantitativamente.** La compresión ocurre por petición y por trabajador de Apache. Con brotli 11 y `lorem.txt`, 10 clientes simultáneos saturan 10 núcleos durante 7 segundos cada uno; el servidor deja de responder para todos los demás. El ahorro de 3,4 % de ancho de banda frente a brotli 5 es irrelevante comparado con perder la capacidad de atender la carga.

El punto de equilibrio se puede formular así: la compresión vale la pena mientras el tiempo de CPU que consume sea menor que el tiempo de transmisión que ahorra. Para `lorem.txt` sobre 10 Mbps, gzip 6 ahorra ~1,6 s de transmisión y cuesta 18 ms de CPU — relación de 88:1 a favor. Brotli 11 ahorra 1,62 s y cuesta 7,05 s — relación **desfavorable de 1:4,3**. Es un caso donde comprimir más hace la respuesta más lenta.

---

## 11. Contenido estático vs dinámico y configuración recomendada

### Cuándo precomprimir en disco

La precompresión resuelve exactamente el problema del punto anterior: **el costo de CPU se paga una sola vez, en el momento del despliegue, no en cada petición**. Con brotli 11, `lorem.txt` cuesta 7 segundos comprimir; precomprimido, esos 7 segundos se gastan una vez y las peticiones posteriores solo leen el archivo `.br` del disco y lo sirven tal cual.

Precomprimir es apropiado cuando el contenido es **estático y su tasa de lectura supera ampliamente la de escritura**: bundles de JavaScript y CSS versionados, documentación, datasets, assets de un sitio generado estáticamente. En esos casos brotli 11 es la elección correcta, porque su único inconveniente —el costo de compresión— desaparece.

Comprimir al vuelo es obligatorio cuando la respuesta **se genera en cada petición**: HTML renderizado por una aplicación, respuestas de API con datos de base de datos, contenido personalizado por usuario. Ahí no hay nada que precomprimir porque el contenido no existe antes de la petición.

Implementación de la precompresión con `mod_headers`:

```apache
<IfModule mod_headers.c>
    RewriteEngine On
    RewriteCond %{HTTP:Accept-Encoding} br
    RewriteCond %{REQUEST_FILENAME}\.br -f
    RewriteRule ^(.*)$ $1.br [L]

    <FilesMatch "\.js\.br$">
        Header set Content-Encoding br
        Header append Vary Accept-Encoding
        ForceType text/javascript
    </FilesMatch>
</IfModule>
```

### Configuración recomendada para producción

| Tipo de contenido | Algoritmo | Nivel | Justificación con nuestros datos |
|---|---|---|---|
| Assets estáticos versionados (JS, CSS) | brotli precomprimido | 11 | Costo pagado una vez; hasta 2,3× mejor que gzip |
| HTML dinámico | brotli al vuelo | 4–5 | Calidad 5 dio 7.258 B en 5,9 ms; calidad 11 dio *peor* tamaño en 1,64 s |
| Respuestas JSON de API | brotli al vuelo | 5 | 11.626 B en 6,1 ms; mejor ratio y mejor tiempo que calidad 11 |
| Texto plano, XML, SVG | brotli al vuelo | 5 | Salvo SVG, donde 11 gana 24,8 % si es estático |
| Fallback para clientes sin `br` | gzip | 6 | Punto de rendimientos decrecientes; ahorro 97,8 % en `lorem.txt` |
| Imágenes, video, archivos empaquetados | ninguno | — | Ratio 1,0000 medido; excluir con `SetEnvIfNoCase` |

Configuración resultante:

```apache
<IfModule mod_brotli.c>
    BrotliCompressionQuality 5
    BrotliCompressionWindow 22
    AddOutputFilterByType BROTLI_COMPRESS text/html text/plain text/xml \
        text/css text/javascript application/javascript \
        application/json application/xml image/svg+xml
</IfModule>

<IfModule mod_deflate.c>
    DeflateCompressionLevel 6
    AddOutputFilterByType DEFLATE text/html text/plain text/xml \
        text/css text/javascript application/javascript \
        application/json application/xml image/svg+xml
    SetEnvIfNoCase Request_URI \.(?:gif|jpe?g|png|webp|mp4|avi|zip|gz|pdf)$ \
        no-gzip dont-vary
</IfModule>
```

Ambos módulos conviven: Apache negocia mediante `Accept-Encoding` y prioriza Brotli cuando el cliente lo soporta, lo que verificamos con `curl -H 'Accept-Encoding: br,gzip'` (respondió `Content-Encoding: br`) y en el navegador, donde Chrome anuncia `gzip, deflate, br, zstd` y recibe `br`.

---

## Nota metodológica

Las mediciones iniciales presentaron tiempos anómalos de ~1,67 s en peticiones que debían tomar milisegundos. El valor constante delató un timeout de resolución DNS, no tiempo de compresión. Se corrigió añadiendo `--resolve parcial.empresa.local:80:192.168.50.10` a `curl`, eliminando la consulta DNS del camino crítico. Todos los datos de este documento provienen de la corrida corregida.

Durante la configuración se detectó también que `mod_brotli` cargaba (`brotli.load` enlazado) pero su configuración no se aplicaba, porque `brotli.conf` no estaba enlazado en `mods-enabled`. La causa: `a2enmod` solo enlaza los archivos que existen al momento de ejecutarlo, y en Ubuntu 22.04 el paquete de `mod_brotli` no incluye un `.conf` por defecto. El síntoma era silencioso —respuestas `200 OK` sin compresión— y solo se detectó comparando tamaños. Un caso ilustrativo de que la compresión mal configurada no produce errores, solo desperdicia ancho de banda.
