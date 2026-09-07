#!/bin/bash
# Medicion de compresion HTTP - Apache mod_deflate vs mod_brotli
# Servicios Telematicos - UAO

HOST="http://parcial.empresa.local"
SALIDA="$HOME/resultados.csv"
DEFLATE_CONF="/etc/apache2/mods-available/deflate.conf"
BROTLI_CONF="/etc/apache2/mods-available/brotli.conf"

ARCHIVOS="index.html estilos.css estilos.min.css app.js datos.json feed.xml grafico.svg lorem.txt foto.jpg imagen.png clip.mp4 paquete.zip"

echo "archivo,algoritmo,nivel,tamano_bytes,tamano_base,ratio,ahorro_pct,tiempo_s,content_encoding" > $SALIDA

medir() {
    local archivo=$1 encoding=$2 algoritmo=$3 nivel=$4 base=$5
    local r t enc ratio ahorro
    # Promedio de 3 corridas para el tiempo
    t=0
    for i in 1 2 3; do
        r=$(curl -s --resolve parcial.empresa.local:80:192.168.50.10 -H "Accept-Encoding: $encoding" -o /dev/null \
            -w "%{size_download} %{time_total}" $HOST/$archivo)
        t=$(echo "$t + $(echo $r | cut -d' ' -f2)" | bc -l)
    done
    local size=$(echo $r | cut -d' ' -f1)
    t=$(echo "scale=6; $t / 3" | bc -l)
    enc=$(curl -s --resolve parcial.empresa.local:80:192.168.50.10 -H "Accept-Encoding: $encoding" -I $HOST/$archivo \
          | grep -i "content-encoding" | tr -d '\r' | awk '{print $2}')
    [ -z "$enc" ] && enc="identity"
    ratio=$(echo "scale=4; $size / $base" | bc -l)
    ahorro=$(echo "scale=2; (1 - $ratio) * 100" | bc -l)
    echo "$archivo,$algoritmo,$nivel,$size,$base,$ratio,$ahorro,$t,$enc" >> $SALIDA
}

# ---------- Linea base ----------
echo ">>> Midiendo linea base (identity)..."
declare -A BASE
for a in $ARCHIVOS; do
    b=$(curl -s --resolve parcial.empresa.local:80:192.168.50.10 -H "Accept-Encoding: identity" -o /dev/null -w "%{size_download}" $HOST/$a)
    BASE[$a]=$b
    medir $a identity ninguno 0 $b
done

# ---------- gzip niveles 1, 6, 9 ----------
for nivel in 1 6 9; do
    echo ">>> Midiendo gzip nivel $nivel..."
    sudo sed -i "s/DeflateCompressionLevel .*/DeflateCompressionLevel $nivel/" $DEFLATE_CONF
    sudo systemctl restart apache2
    sleep 2
    for a in $ARCHIVOS; do
        medir $a gzip gzip $nivel ${BASE[$a]}
    done
done

# ---------- brotli calidades 5 y 11 ----------
for cal in 5 11; do
    echo ">>> Midiendo brotli calidad $cal..."
    sudo sed -i "s/BrotliCompressionQuality .*/BrotliCompressionQuality $cal/" $BROTLI_CONF
    sudo systemctl restart apache2
    sleep 2
    for a in $ARCHIVOS; do
        medir $a br brotli $cal ${BASE[$a]}
    done
done

# ---------- Restaurar valores por defecto ----------
sudo sed -i "s/DeflateCompressionLevel .*/DeflateCompressionLevel 6/" $DEFLATE_CONF
sudo sed -i "s/BrotliCompressionQuality .*/BrotliCompressionQuality 11/" $BROTLI_CONF
sudo systemctl restart apache2

echo ""
echo "=== Mediciones completadas: $SALIDA ==="
column -s, -t < $SALIDA
