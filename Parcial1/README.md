\# Primer Parcial — Servicios Telemáticos



Universidad Autónoma de Occidente · Facultad de Ingeniería

Juan José Baloco Sánchez — 2230722



Microproyecto integrador: DNS tolerante a fallos · Optimización de tráfico web · Publicación segura



\## Topología



| VM | Rol | IP |

|---|---|---|

| maestro | DNS primario (type master) | 192.168.50.2 |

| esclavo | DNS secundario (type slave) | 192.168.50.3 |

| web | Cliente DNS + Apache | 192.168.50.10 |



Dominio: `empresa.local` · Zona inversa: `50.168.192.in-addr.arpa`



\## Contenido



\- `infraestructura/` — Vagrantfile y scripts de aprovisionamiento

\- `parte1-dns/` — named.conf, zonas directa e inversa, clave TSIG y logs de auditoría

\- `parte2-apache/` — Configuración de mod\_deflate y mod\_brotli, scripts de medición, resultados.csv con 72 mediciones, análisis crítico y capturas

\- `parte3-tunel/` — Página personalizada



\## Nota sobre la clave TSIG



El secreto real no se publica. `parte1-dns/claves/esclavo.key.ejemplo` contiene la

estructura del archivo con el valor redactado y las instrucciones para regenerarlo

con `tsig-keygen`.



\## Declaración de uso de asistentes de IA



Durante el desarrollo se utilizó un asistente de IA (Claude, de Anthropic) como apoyo

en la depuración de errores de configuración y la redacción de los scripts de

automatización. Todas las decisiones de diseño fueron tomadas y verificadas por el

grupo, todos los comandos fueron ejecutados manualmente sobre la infraestructura, y

el grupo puede explicar cada línea de configuración entregada.

