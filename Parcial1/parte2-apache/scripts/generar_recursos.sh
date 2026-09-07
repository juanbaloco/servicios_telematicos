#!/bin/bash
# Genera los recursos de prueba para medir compresion
# Servicios Telematicos - UAO
DEST=/var/www/parcial
sudo mkdir -p $DEST
cd /tmp

# 1. HTML (~300 KB)
{
echo "<!DOCTYPE html><html><head><meta charset='utf-8'>"
echo "<title>Parcial Servicios Telematicos</title></head><body>"
for i in $(seq 1 3000); do
  echo "<div class='item' id='item-$i'><h2>Seccion $i</h2><p>Contenido de prueba para medir compresion HTTP en Apache con mod_deflate y mod_brotli.</p></div>"
done
echo "</body></html>"
} > index.html

# 2. CSS sin minificar (~150 KB)
for i in $(seq 1 2000); do
  echo ".clase-$i { color: #333333; background-color: #ffffff; margin: 10px; padding: 5px; border: 1px solid #cccccc; }"
done > estilos.css

# 3. CSS minificado
tr -d '\n ' < estilos.css > estilos.min.css

# 4. JavaScript (~200 KB)
for i in $(seq 1 2500); do
  echo "function procesarDatos$i(entrada) { var resultado = entrada * $i; console.log('Procesando ' + resultado); return resultado; }"
done > app.js

# 5. JSON (~400 KB)
{
echo '{"registros":['
for i in $(seq 1 4000); do
  printf '{"id":%d,"nombre":"Usuario %d","email":"usuario%d@empresa.local","activo":true}' $i $i $i
  [ $i -lt 4000 ] && echo "," || echo ""
done
echo ']}'
} > datos.json

# 6. XML (~200 KB)
{
echo '<?xml version="1.0" encoding="UTF-8"?><feed>'
for i in $(seq 1 2000); do
  echo "<entrada><id>$i</id><titulo>Noticia $i</titulo><contenido>Texto de la noticia</contenido></entrada>"
done
echo '</feed>'
} > feed.xml

# 7. SVG
{
echo '<svg xmlns="http://www.w3.org/2000/svg" width="800" height="600">'
for i in $(seq 1 1500); do
  echo "<circle cx=\"$((RANDOM % 800))\" cy=\"$((RANDOM % 600))\" r=\"5\" fill=\"#3366cc\" stroke=\"#000000\"/>"
done
echo '</svg>'
} > grafico.svg

# 8. Texto plano (> 1 MB)
for i in $(seq 1 15000); do
  echo "Linea $i: Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."
done > lorem.txt

# 9. Binarios (ya comprimidos)
head -c 500000 /dev/urandom > foto.jpg
head -c 300000 /dev/urandom > imagen.png
head -c 800000 /dev/urandom > clip.mp4
zip -q paquete.zip lorem.txt

sudo cp index.html estilos.css estilos.min.css app.js datos.json feed.xml grafico.svg lorem.txt foto.jpg imagen.png clip.mp4 paquete.zip $DEST/
sudo chown -R www-data:www-data $DEST
ls -lh $DEST
