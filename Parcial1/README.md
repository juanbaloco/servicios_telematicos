# Primer Parcial - Servicios Telematicos

Microproyecto integrador: DNS tolerante a fallos, optimizacion de trafico web y publicacion segura.

Universidad Autonoma de Occidente - Facultad de Ingenieria

## Integrantes

- Juan Jose Baloco Sanchez - 2230722
- Carlos Andres Chalaca Patino - 2226213
- Daniel Santiago Truque Martinez - 1108561484

## Topologia

| VM | Rol | IP |
|---|---|---|
| maestro | DNS primario (type master) | 192.168.50.2 |
| esclavo | DNS secundario (type slave) | 192.168.50.3 |
| web | Cliente DNS + Apache | 192.168.50.10 |

Dominio: `empresa.local` - Zona inversa: `50.168.192.in-addr.arpa`

## Contenido

- `infraestructura/` - Vagrantfile y scripts de aprovisionamiento
- `parte1-dns/` - named.conf, zonas directa e inversa, clave TSIG y logs de auditoria
- `parte2-apache/` - Configuracion de mod_deflate y mod_brotli, scripts de medicion, resultados.csv con 72 mediciones, analisis critico y capturas
- `parte3-tunel/` - Pagina personalizada

## Nota sobre la clave TSIG

El secreto real no se publica. El archivo `parte1-dns/claves/esclavo.key.ejemplo`
contiene la estructura con el valor redactado y las instrucciones para regenerarlo
con `tsig-keygen`.

## Declaracion de uso de asistentes de IA

Durante el desarrollo se utilizo un asistente de IA (Claude, de Anthropic) como apoyo
en la depuracion de errores de configuracion y la redaccion de los scripts de
automatizacion. Todas las decisiones de diseno fueron tomadas y verificadas por el
grupo, todos los comandos fueron ejecutados manualmente sobre la infraestructura, y
el grupo puede explicar cada linea de configuracion entregada.
