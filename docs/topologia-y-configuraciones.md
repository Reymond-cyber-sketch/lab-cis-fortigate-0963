# Infraestructura reutilizada y conexiones

Proyecto original: FortiGate-DMZ-VLAN-Security-Lab. Se conserva como soporte del objetivo de auditoría de FGT-USER. El firewall tiene FortiOS 7.4.12 build2902, licencia Valid, 1 CPU y aproximadamente 2 GB RAM. Su salida de estado indicó que no hay disco local de logs. No se utilizó ni se acreditó licencia de CIS Security Rating.

| Enlace confirmado por captura | Función |
|---|---|
| FGT-USER Ethernet0 → ISP Ethernet1 | WAN |
| FGT-USER Ethernet1 → SW-LAB Ethernet2 | Tránsito interno y gestión |
| FGT-USER Ethernet2 → SW2-DMZ Ethernet0 | DMZ |
| MGMTCloud eth0 → SW-LAB Ethernet1 | Acceso Windows / VMnet1 |
| SW2-DMZ Ethernet3 → DB-SERVER eth0 | Servidor de base de datos |

Las cinco capturas originales de enlaces se conservan en imagenes/07 a 11. La equivalencia de interfaces del FortiGate queda documentada como port1/WAN, port2/tránsito y port3/DMZ. El ISP tiene interfaces RouterOS renombradas ether7 a ether12; su export es la referencia de asignación IP y no se supone una equivalencia numérica universal con etiquetas GNS3.

USER-ROUTER utiliza ether1 para 10.10.10.2/30 y ether2 para las subinterfaces VLAN10-USERS y VLAN20-ADMIN. Sus gateways son 10.24.96.1/25 y 10.24.97.1/25 y mantiene DHCP para ambas. El FortiGate conserva rutas a esas redes vía 10.10.10.2, una ruta por defecto vía 198.51.100.97 y la DMZ conectada 10.24.96.128/28.

Las políticas observadas de FortiGate son VLAN20_TO_DMZ_SSH, VLAN10_TO_CAJA_HTTPS y DMZ_TO_UPDATES_ONLY. Están documentadas en el backup final; no fueron objeto de cambio por el script ni de una nueva validación funcional de aplicaciones durante esta práctica.

El objetivo de seguridad demostrado es retirar la administración por WAN y reforzar controles de acceso manteniendo la gestión interna. No requiere afirmar que todos los servicios heredados se probaron de nuevo.
