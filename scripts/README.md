# Scripts utilizados

Auditar-FortiGate.ps1 es el archivo que generó los informes entregados: su hash coincide con ScriptSHA256 en ambos JSON. Preparar-Entorno.ps1 instala e importa Posh-SSH 4.0.0 en Windows; equipos.json declara el firewall y su clave de host ya verificada.

## Preparar Windows

Desde la raíz del repositorio descargado, ejecutar una línea a la vez en PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Preparar-Entorno.ps1
```

## Solo auditoría

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Auditar-FortiGate.ps1 -Modo Auditar -Inventario .\scripts\equipos.json -Salida .\informes
```

## Aplicar y volver a comprobar

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Auditar-FortiGate.ps1 -Modo Aplicar -Inventario .\scripts\equipos.json -Salida .\informes
```

Los comandos anteriores suponen que el contenido del ZIP está en la carpeta actual. Las contraseñas se introducen localmente de forma oculta. No se modifica permanentemente la política de ejecución de Windows. La preparación requiere acceso a PowerShell Gallery.

El modo Auditar limita los comandos remotos a get system status y show full-configuration de global/interfaces. El modo Aplicar genera un plan y un archivo de reversión antes de enviar los cambios. Rechaza quitar allowaccess si la IP de conexión está en la WAN que se pretende endurecer. Después abre una nueva sesión y vuelve a leer; una configuración no leída no se supone conforme.

La huella se conserva como SHA256:base64 en JSON y se convierte al resumen base64 al registrarla en Posh-SSH 4.0.0. No se utilizan AcceptKey ni Force para saltar la comprobación del servidor. El inventario puede contener varios FortiGate 7.4.x; cada uno necesita su propia clave previamente verificada. No es un descubridor de CIDR ni un auditor genérico de otros fabricantes.

El script incluye autopruebas previas a la conexión para analizar bloques anidados, calcular cambios y rechazar lecturas incompletas o una conexión de gestión por WAN. Se pueden ejecutar sin instalar el módulo ni conectar al equipo:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Auditar-FortiGate.ps1 -Autoprueba
```

Las remediaciones no forman una transacción. Si un comando falla puede haber cambios previos; se registra el error y se intenta releer. Los archivos de reversión cubren solo los parámetros afectados. La repetición sobre un equipo conforme no reabre servicios ni reduce valores ya más estrictos.

El generador diagramas/generar_diagramas.py solo renderiza los archivos DOT con Graphviz; no interviene sobre equipos de red.
