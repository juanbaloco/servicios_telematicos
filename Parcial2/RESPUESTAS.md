# Segundo Parcial – Respuestas a las preguntas del enunciado

**Estudiante:** Juan José Baloco Sánchez · **Código:** 2230722  
**Estudiante:** Carlos Andres Chalaca Patino · **Código:** 2226213  
**Estudiante:** Daniel Santiago Truque Martinez · **Código:** 1108561484

Topología usada: `<ip pública>` = **192.168.56.10** (eth2 de servidor1), servidor1 eth1 = 192.168.50.3, servidor2 = 192.168.50.2, cliente = 192.168.56.20 (VM) y 192.168.56.1 (Windows con FileZilla).

---

## Primera parte – FTPS protegido por UFW

### Punto 1 – Servidor 2 no es alcanzable directamente

servidor1 tiene política `deny (incoming)` y `deny (routed)`, reenvío IP activo (`net/ipv4/ip_forward=1`) y DNAT hacia 192.168.50.2 en `/etc/ufw/before.rules`. Servidor2 está en una red interna de VirtualBox (`intnet`) a la que el cliente no tiene acceso. Desde el cliente:

```
$ ip route get 192.168.50.2      -> 192.168.50.2 via 10.0.2.2 dev eth0   (no hay ruta interna)
$ ping -c 2 192.168.50.2         -> 100% packet loss
$ nc -zv -w 5 192.168.50.2 21    -> timed out
```

### Punto 3 – Diferencia entre `ufw allow` y `ufw route allow`

| | `ufw allow` | `ufw route allow` |
|---|---|---|
| Cadena de iptables | INPUT | FORWARD |
| Tráfico que controla | El que va dirigido **a la propia máquina** | El que **atraviesa** la máquina hacia otra |
| Uso en este parcial | `22/tcp` para administrar servidor1 por SSH | 21, 50000:50010 y 22 hacia 192.168.50.2 |

Como el DNAT cambia el destino del paquete de 192.168.56.10 a 192.168.50.2, ese tráfico ya no es para servidor1 sino que se reenvía. Por eso un `ufw allow 21` no sirve: hace falta `ufw route allow`. Prueba realizada: sin la regla route del 21, `nc -zv 192.168.56.10 21` termina en *timeout* (la política `deny (routed)` descarta el paquete); al agregarla, la conexión responde `succeeded` y la sesión FTPS funciona.

### Punto 4 – Propósito de cada regla

```
$ sudo ufw status verbose
Default: deny (incoming), allow (outgoing), deny (routed)
22/tcp                               ALLOW IN    Anywhere
192.168.50.2 50000:50010/tcp on eth1 ALLOW FWD   Anywhere on eth2
192.168.50.2 21/tcp on eth1          ALLOW FWD   Anywhere on eth2
192.168.50.2 22/tcp on eth1          ALLOW FWD   Anywhere on eth2

$ sudo iptables -t nat -L -n -v
DNAT  tcp  eth2  dpt:21            to:192.168.50.2:21
DNAT  tcp  eth2  dpts:50000:50010  to:192.168.50.2
DNAT  tcp  eth2  dpt:2222          to:192.168.50.2:22
MASQUERADE  all  out eth1  -> 192.168.50.2
```

| Regla | Propósito en FTPS |
|---|---|
| `ALLOW IN 22/tcp` | Administración SSH de servidor1 (no tiene que ver con FTPS) |
| DNAT 21 → 192.168.50.2:21 | Publica el **canal de control**: saludo 220, `AUTH TLS` y, ya cifrados, usuario, contraseña y comandos |
| DNAT 50000:50010 → 192.168.50.2 | Publica el **canal de datos** en modo pasivo: vsftpd anuncia un puerto del rango y esta regla lleva la conexión hasta servidor2 |
| MASQUERADE hacia eth1 | servidor2 ve las conexiones como si vinieran de servidor1, así responde por servidor1 y no por su salida NAT de VirtualBox |
| `ALLOW FWD` 21 y 50000:50010 | Permiten en la cadena FORWARD exactamente lo que el DNAT redirige; lo demás lo descarta `deny (routed)` |

En la tabla nat los contadores suman solo el primer paquete de cada conexión (el resto lo traduce conntrack). Las líneas `-F PREROUTING` / `-F POSTROUTING` al inicio del bloque `*nat` evitan que `ufw reload` duplique las reglas.

### Punto 6 – Modo pasivo

Configuración: `pasv_min_port=50000`, `pasv_max_port=50010`, `pasv_address=192.168.56.10`.

**(a) ¿Por qué el rango pasivo debe coincidir con las reglas del firewall?**
En modo pasivo vsftpd elige un puerto de datos dentro de 50000-50010 y se lo comunica al cliente. Si el firewall no reenvía y permite exactamente ese rango, la conexión de datos se bloquea: el inicio de sesión funciona, pero el listado (`ls`) o la transferencia se quedan esperando y fallan por *timeout*.

**(b) ¿Por qué, a diferencia de FTP plano, en FTPS el firewall no puede abrir dinámicamente los puertos de datos?**
En FTP plano el módulo de seguimiento de conexiones (`nf_conntrack_ftp`) lee la respuesta `227 Entering Passive Mode` dentro del canal de control, descubre el puerto de datos y lo abre temporalmente como conexión RELATED. En FTPS, después de `AUTH TLS` el canal de control va cifrado: el firewall no puede leer la respuesta PASV y no sabe qué puerto abrir. Por eso hay que dejar abierto un rango fijo y conocido.

**(c) ¿Qué ocurre si `pasv_address` no se configura detrás de NAT?**
vsftpd anunciaría su IP real, 192.168.50.2, en la respuesta PASV. El cliente intentaría abrir el canal de datos hacia esa IP privada, que no puede alcanzar, y fallarían todos los listados y transferencias (el login sí funcionaría). Con `pasv_address=192.168.56.10` anuncia la IP pública, que sí pasa por el DNAT de servidor1.

### Punto 7 – Certificado presentado en FileZilla

| Campo | Valor |
|---|---|
| Sujeto | C=CO, ST=Valle, L=Cali, O=UAO, CN=192.168.56.10 |
| Emisor | C=CO, ST=Valle, L=Cali, O=UAO, CN=CA-2230722 |
| Vigencia | 5 oct 2026 – 5 oct 2027 |
| Huella SHA-256 | `5E:26:04:B2:9E:DB:4A:CF:FA:71:C7:F3:AA:9F:6B:09:7C:88:0A:CF:20:DA:26:FF:F8:85:87:29:DB:8A:2E:72` |

La huella es idéntica a la de `openssl x509 -in servidor.crt -noout -fingerprint -sha256`. FileZilla lo marca como "desconocido" porque la CA-2230722 es propia del laboratorio y no está en el almacén de confianza de Windows. Se listó el directorio, se subió `2230722.txt` y se descargó de vuelta; el archivo quedó en `/home/ftp2230722/` de servidor2.

### Punto 8 – `openssl s_client`

```
$ openssl s_client -connect 192.168.56.10:21 -starttls ftp -CAfile ca.crt
depth=1 C = CO, ST = Valle, L = Cali, O = UAO, CN = CA-2230722
depth=0 C = CO, ST = Valle, L = Cali, O = UAO, CN = 192.168.56.10
...
New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Server Temp Key: ECDH, prime256v1, 256 bits
Verify return code: 0 (ok)
220 (vsFTPd 3.0.5)
```

- **El certificado corresponde al servidor configurado:** sujeto `CN=192.168.56.10`, emitido por `CN=CA-2230722`.
- **Cadena de confianza válida:** CA (depth 1) → servidor (depth 0), `Verify return code: 0 (ok)`.
- **Versión de TLS:** TLSv1.3.
- **Suite de cifrado:** `TLS_AES_256_GCM_SHA384` (AES de 256 bits en modo GCM, SHA-384), con intercambio ECDH que da secreto perfecto hacia adelante.
- El código fue 0. Si no lo fuera, lo habitual es no pasar el `-CAfile` correcto o que el certificado no esté firmado por esa CA (códigos 19/21).
- `220 (vsFTPd 3.0.5)` confirma que responde vsftpd de servidor2 aunque la conexión fue a la IP de servidor1.

### Punto 9 – Capturas FTP sin cifrar vs FTPS

| Captura | Qué se identifica |
|---|---|
| FTP sin cifrar (TLS desactivado temporalmente) | `USER ftp2230722` y `PASS` en texto plano; en el canal ftp-data, el contenido de `bienvenida.txt` legible |
| FTPS – canal de control (puerto 21) | Solo `220`, **`AUTH TLS`** y `234 Proceed with negotiation`; luego **handshake TLS 1.3** (Client Hello, Hello Retry Request, Server Hello) y `Application Data` |
| FTPS – canal de datos (puerto pasivo 50010) | Su propio handshake TLS y **tráfico cifrado**; el contenido del archivo es ilegible |

En FTPS solo quedan visibles metadatos: IPs, puertos, tamaños y la ALPN `x-filezilla-ftp` del Client Hello.

---

## Segunda parte – DNS sobre TLS (DoT)

### Punto 10 – `DNSOverTLS=yes` vs `DNSOverTLS=opportunistic`

```
[Resolve]
DNS=1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google
FallbackDNS=1.0.0.1#cloudflare-dns.com 8.8.4.4#dns.google
DNSOverTLS=yes
Domains=~.
```

- **`yes` (estricto):** solo DoT. Si no se puede establecer TLS con el resolver en el puerto 853, o su certificado no valida, la consulta **falla**. Nunca se degrada a DNS en texto plano.
- **`opportunistic`:** intenta DoT y, si no lo logra, **cae a DNS clásico sin cifrar** (UDP/53). Siempre resuelve, pero un atacante que bloquee el 853 puede forzar esa degradación y ver las consultas.

`/etc/resolv.conf` apunta al stub `127.0.0.53` (systemd-resolved).

### Punto 11 – Evidencia de DoT activo

```
$ resolvectl status
Global
           Protocols: -LLMNR -mDNS +DNSOverTLS DNSSEC=no/unsupported
         DNS Servers: 1.1.1.1#cloudflare-dns.com 8.8.8.8#dns.google
Fallback DNS Servers: 1.0.0.1#cloudflare-dns.com 8.8.4.4#dns.google
          DNS Domain: ~.
Link 2 (eth0)
Current Scopes: none
```

`+DNSOverTLS` en Protocols confirma DoT activo; los servidores son los configurados y eth0 no tiene DNS propios.

### Punto 12 – ¿Por qué `dig @8.8.8.8 <dominio>` no utilizaría DoT?

Con `@8.8.8.8`, `dig` no pasa por systemd-resolved: le envía la consulta **directamente** a Google por **UDP al puerto 53, en texto plano**. `dig` no implementa DoT por sí solo; el cifrado lo agrega systemd-resolved únicamente a las consultas que llegan al stub `127.0.0.53`. En cambio `resolvectl query uao.edu.co` reporta "Data was acquired via local or encrypted transport: yes" y `dig wikipedia.org` (sin `@`) muestra `SERVER: 127.0.0.53#53`.

### Punto 13 – Información expuesta en DNS sin cifrar

| Captura | Filtro | Resultado |
|---|---|---|
| DoT activo | `tcp.port == 853` | Handshake TCP y TLS con 1.1.1.1:853 (SNI `cloudflare-dns.com`) y luego solo Application Data; no aparecen los dominios consultados |
| `DNSOverTLS=no` | `udp.port == 53` | `Standard query A unicef.org`, `AAAA unicef.org`, `A bbc.com` y sus respuestas con las IPs |

En el DNS sin cifrar queda expuesto: el **nombre de cada dominio** consultado, el **tipo de registro** (A, AAAA…), las **IPs de respuesta**, los TTL, el identificador de la consulta y **quién pregunta**. Cualquiera en la red puede reconstruir el historial de navegación y, al no haber integridad, falsificar respuestas.

### Punto 14 – Preguntas teóricas

**¿Qué sigue siendo visible con DoT activo?**
- La **IP del resolver** (1.1.1.1) y el **puerto 853**: se sabe que se usa DoT y con qué proveedor.
- El **SNI** del Client Hello (`cloudflare-dns.com`).
- Los **tamaños y tiempos** de los paquetes, que permiten análisis de tráfico.
- La **conexión posterior** al sitio: su IP de destino y el SNI de HTTPS lo revelan igual. DoT protege la consulta DNS, no la navegación.

**¿Qué ocurre si un firewall bloquea el puerto 853?**
- Con `DNSOverTLS=yes`: la resolución de nombres **falla** (no hay navegación por nombre), pero ninguna consulta sale en claro.
- Con `DNSOverTLS=opportunistic`: el cliente **cae a UDP/53 sin cifrar**; sigue funcionando pero sin privacidad.

**DoT vs DoH en este escenario:**
- **DoT** usa un puerto dedicado (853): fácil de identificar y de bloquear por un administrador.
- **DoH** viaja dentro de HTTPS por el 443, mezclado con el tráfico web: muy difícil de bloquear sin romper la navegación, pero también más difícil de supervisar. Ambos cifran igual; cambia la visibilidad y la facilidad de bloqueo.

---

## Tercera parte – SFTP protegido por UFW

### Punto 15 – Usuario SFTP enjaulado

```
Match User sftp_2230722
    ChrootDirectory /sftp/%u
    ForceCommand internal-sftp
    PasswordAuthentication yes
    AllowTcpForwarding no
    X11Forwarding no
    PermitTunnel no
```

`sftp` funciona (`pwd` → `/`, `ls` → `archivos`). `ssh` es rechazado con *"This service allows sftp connections only."*

### Punto 16 – Reenvío 2222 → 192.168.50.2:22

DNAT `--dport 2222 -j DNAT --to-destination 192.168.50.2:22` y `ufw route allow in on eth2 out on eth1 to 192.168.50.2 port 22 proto tcp`. Sin la regla route, la conexión al 2222 da *timeout*; con ella, funciona. `nc -zv 192.168.50.2 22` desde el cliente siempre falla. La regla route usa el puerto **22** (no 2222) porque el DNAT ocurre en PREROUTING, antes de que el filtro FORWARD evalúe el paquete.

### Punto 17 – Huella de la clave de host

Primera conexión `sftp -P 2222 sftp_2230722@192.168.56.10`:
`ED25519 key fingerprint is SHA256:CifvuKnCFUxaTaHjJPvXJRQcfQVeROGRu5rhIY1FQYs`, idéntica a `ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub` en servidor2. Se hizo `ls`, `put sftp_2230722.txt` y `get sftp_2230722.txt descargado.txt` con el contenido intacto.

### Punto 18 – Captura SFTP y comparación

En la captura del puerto 2222 (decodificado como SSH):
1. **Intercambio de versiones:** `SSH-2.0-OpenSSH_8.9p1 Ubuntu-3ubuntu0.13` de ambos lados (único texto en claro).
2. **Intercambio de claves:** `Key Exchange Init` (algoritmos: curve25519-sha256, sntrup761x25519-sha512, ssh-ed25519, chacha20-poly1305, aes256-gcm, hmac-sha2), `Elliptic Curve Diffie-Hellman Key Exchange Init/Reply` y `New Keys`.
3. **Canal único cifrado:** todo lo siguiente es `Encrypted packet`; autenticación y datos viajan en la misma conexión.

| | FTP plano | FTPS | SFTP |
|---|---|---|---|
| Conexiones TCP | 2 (control + datos) | 3 (dos de control al 21 + datos al 50010) | **1** |
| Puertos | 21 + pasivo | 21 + pasivo | 2222 (→ 22) |
| Qué es visible | Usuario, contraseña, comandos y contenido | `220`, `AUTH TLS`, `234`, handshake TLS por conexión, ALPN | Solo versión SSH-2.0 y lista de algoritmos |

---

## Punto 19 – Tabla comparativa FTPS vs SFTP

| Criterio | FTPS (vsftpd) | SFTP (OpenSSH) |
|---|---|---|
| **Protocolo base** | FTP (RFC 959) con una capa TLS por encima | SSH-2 (subsistema sftp); no es FTP |
| **Número de conexiones y puertos** | Varias: control en el **21** + una conexión de datos por cada listado o transferencia en el rango pasivo **50000-50010** | **Una sola** conexión TCP, puerto **22** (publicado como 2222) |
| **Autenticación del servidor** | **Certificado X.509** firmado por una CA (`CA-2230722`); el cliente valida la cadena de confianza | **Clave de host SSH** (ED25519); el cliente acepta la huella en la primera conexión (TOFU) y la guarda en `known_hosts` |
| **Momento en que inicia el cifrado** | Después del saludo en claro, cuando el cliente envía **`AUTH TLS`** (TLS explícito) | Desde el **intercambio de claves**; solo versiones y lista de algoritmos van en claro, la autenticación ya va cifrada |
| **Facilidad para atravesar firewalls/NAT** | **Difícil**: rango de puertos abierto, `pasv_address` obligatorio y el firewall no puede leer la respuesta PASV cifrada | **Fácil**: un solo puerto y una sola regla |
| **Facilidad de configuración** | Media/alta: CA + certificado, TLS en vsftpd, rango pasivo coherente, 2 DNAT y 2 reglas route | Baja: un usuario, un bloque `Match` en `sshd_config`, 1 DNAT y 1 regla route |

**Conclusión (con base en las evidencias):** para un entorno con restricciones de firewall estrictas, **SFTP es más adecuado**. En este laboratorio FTPS necesitó DNAT del puerto 21 y de 11 puertos pasivos, dos reglas `route`, MASQUERADE y `pasv_address`, y la captura muestra tres conexiones TCP con un handshake TLS cada una. SFTP necesitó un solo DNAT (2222→22) y una sola regla `route`, y la captura muestra una única conexión cifrada desde el intercambio de claves. Menos puertos abiertos significa menor superficie de ataque y una administración más simple. FTPS conserva su lugar cuando se exige un certificado X.509 de una CA reconocida o compatibilidad con clientes FTP tradicionales.
