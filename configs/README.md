# Configuraciones y alcance

FGT-USER-final-enmascarado.conf conserva los bytes del backup FortiOS aportado. Se comprobó la presencia de FortinetPasswordMask en campos sensibles; no se encontraron valores con el prefijo ENC en las líneas de configuración revisadas. Es una copia para documentación: los secretos originales no se pueden recuperar de ella. Conservar un backup privado separado para restauración real.

El respaldo refleja admin-lockout-duration=900 y port1 sin allowaccess. Los valores predeterminados de 3 intentos y 5 minutos no aparecen necesariamente en un backup compacto; los informes originales incluyen las lecturas de show full-configuration que sí los verificaron.

ISP.rsc y USER-ROUTER.rsc transcriben los exports aportados por el usuario el 12 de noviembre. No se aplicaron medidas CIS a esos routers en esta práctica. USER-ROUTER se incluye porque enruta las VLANs de clientes hacia el firewall; no implica que se haya modificado durante el hardening.

No importar estos archivos sobre equipos ya configurados como si fueran comandos de actualización: los add de RouterOS y los bloques de configuración requieren un contexto de restauración apropiado. Los exports no son backups binarios ni contienen todas las credenciales y estados dinámicos.

SW-LAB y SW2-DMZ se documentan por su función y conexiones observadas. No se aportó un archivo de configuración de sus puertos GNS3. No se inventan running-configs, VLANs de puertos ni resultados de auditoría para esos nodos. El objetivo auditado del alcance es FGT-USER.
