# Segundo Parcial – Servicios Telemáticos (UAO)

**Estudiante:** Juan José Baloco Sánchez · **Código:** 2230722 
**Estudiante:** Carlos Andres Chalaca Patino - **Codigo:** 2226213
**Estudiante:** Daniel Santiago Truque Martinez - **Codigo:** 1108561484

## Topología

```
Cliente (FileZilla en Windows 192.168.56.1 / VM cliente 192.168.56.20)
        |  red "pública" 192.168.56.0/24 (host-only)
Servidor 1 – UFW        eth2 = 192.168.56.10   <-- <ip pública>
                        eth1 = 192.168.50.3
        |  red interna 192.168.50.0/24 (intnet: el cliente no tiene acceso)
Servidor 2 – vsftpd (FTPS) + OpenSSH (SFTP)   eth1 = 192.168.50.2
```

La `<ip pública>` del enunciado corresponde en este entorno a **192.168.56.10**.

## Contenido

| Carpeta / archivo | Máquina | Descripción |
|---|---|---|
| `Vagrantfile` | – | Definición de las tres VMs y sus redes |
| `servidor1/before.rules` | Servidor 1 | Reglas NAT: DNAT 21, 50000:50010 y 2222→22 hacia 192.168.50.2, más MASQUERADE |
| `servidor1/user.rules`, `servidor1/ufw` (`/etc/default/ufw`), `servidor1/sysctl.conf` | Servidor 1 | Reglas `ufw route`, políticas por defecto y reenvío IP |
| `servidor1/ufw_status.txt`, `servidor1/iptables_nat.txt` | Servidor 1 | Evidencia: `ufw status verbose` e `iptables -t nat -L -n -v` |
| `servidor2/vsftpd.conf` | Servidor 2 | FTPS con TLS explícito, rango pasivo 50000-50010 y `pasv_address` |
| `servidor2/sshd_config` | Servidor 2 | Usuario `sftp_2230722` con `ChrootDirectory` y `ForceCommand internal-sftp` |
| `servidor2/ca.crt`, `servidor2/servidor.crt` | Servidor 2 | CA y certificado del servidor (las claves privadas **no** se publican) |
| `cliente/resolved.conf` | Cliente | DNS sobre TLS (`DNSOverTLS=yes`) con Cloudflare y Google |
| `cliente/99-sin-dns-dhcp.yaml`, `cliente/sin-dns.conf` | Cliente | Evitan que el DHCP de la red NAT imponga servidores DNS sin cifrar |
| `capturas/` | – | Capturas Wireshark/tcpdump: FTPS, DoT, DNS plano y SFTP |

## Partes

1. **FTPS protegido por UFW** – Servidor 1 es el único punto de entrada (`deny` entrante y enrutado), reenvía el 21 y el rango pasivo a Servidor 2.
2. **DNS sobre TLS** – systemd-resolved en el cliente con `DNSOverTLS=yes`; verificado con capturas en el puerto 853 frente al 53.
3. **SFTP protegido por UFW** – puerto externo 2222 reenviado al 22 de Servidor 2, usuario enjaulado sin acceso a shell.
