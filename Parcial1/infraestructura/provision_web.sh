#!/bin/bash
# Provision del servidor web y cliente
# Servicios Telematicos - UAO

apt-get update

# Servidor web Apache
apt-get install --yes apache2

# Modulos de compresion (Parte 2)
a2enmod deflate
a2enmod brotli
a2enmod headers
systemctl restart apache2

# Herramientas de prueba y captura
apt-get install --yes dnsutils curl wget tcpdump