#!/bin/bash
# Provision de los servidores DNS (maestro y esclavo)
# Servicios Telematicos - UAO

apt-get update

# Servidor de nombres BIND9
apt-get install --yes bind9 bind9utils

# Herramientas de consulta DNS (dig, host, nslookup)
apt-get install --yes dnsutils