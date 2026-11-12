# Procedencia de los archivos

- La configuración completa enmascarada de FortiGate es el archivo original aportado por el usuario, renombrado para identificar su función.
- Los `.rsc` de ISP y USER-ROUTER transcriben sus exports aportados; no incluyen los prompts ni el comando /export.
- Los diez archivos de informes, plan y reversión se extrajeron sin modificar sus bytes del ZIP original. Solo se normalizaron los separadores de ruta de Windows.
- Las figuras de los informes se generaron a partir de sus JSON originales. Son visualizaciones documentales, no capturas originales del terminal.
- La prueba WAN se conserva como transcripción exacta de las líneas de resultado recibidas, sin inventar hora de ejecución.
- Las imágenes de GNS3 y de acceso SSH son capturas originales aportadas por el usuario.
- SHA256 del script publicado y registrado por ambas ejecuciones: `EB149A37FB880AD5F0B078CA40014F2C0D2AE086B73AB4F9E43EF0BECFC8AE16`.

La fecha de los informes es la de Windows con su desplazamiento -04:00. Los exports y el nombre del backup conservan las horas mostradas por los equipos; no se afirma sincronización horaria entre ellos.
