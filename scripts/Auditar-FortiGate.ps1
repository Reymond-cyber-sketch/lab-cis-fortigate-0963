#requires -Version 5.1
<#
Evaluacion PARCIAL: CIS FortiGate 7.4.x Benchmark v1.0.1, recomendaciones
1.3, 2.2.2 y 2.4.4. No es CIS-CAT ni certificacion de cumplimiento completo.
Auditar no envia comandos de configuracion al dispositivo.
Aplicar modifica solo los parametros elegidos y vuelve a leer el dispositivo.
#>
[CmdletBinding()]
param(
    [ValidateSet('Auditar','Aplicar')][string]$Modo = 'Auditar',
    [string]$Inventario = '',
    [string]$Salida = '',
    [switch]$Autoprueba
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Resolver las rutas una vez terminado el enlace de parametros.
$scriptFullPath = [string]$PSCommandPath
if ([string]::IsNullOrWhiteSpace($scriptFullPath)) {
    $scriptFullPath = [string]$MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($scriptFullPath)) {
    throw 'Ejecuta este codigo como archivo .ps1 mediante powershell.exe -File.'
}
$scriptDirectory = [IO.Path]::GetDirectoryName($scriptFullPath)
if ([string]::IsNullOrWhiteSpace($Inventario)) {
    $Inventario = Join-Path -Path $scriptDirectory -ChildPath 'equipos.json'
}
if ([string]::IsNullOrWhiteSpace($Salida)) {
    $Salida = Join-Path -Path $scriptDirectory -ChildPath 'resultados'
}

function Remove-TerminalCodes {
    param([string]$Text)
    $escape = [char]27
    $clean = [regex]::Replace($Text, "$escape\[[0-?]*[ -/]*[@-~]", '')
    $clean = $clean.Replace("`r",'').Replace([string][char]8,'')
    return $clean.Replace('--More--','')
}

function Read-FortiConfig {
    param([string]$Text,[ValidateSet('global','interface')][string]$Kind)
    $rootLine = 'config system ' + $Kind
    $depth = 0; $started = $false; $complete = $false; $current = $null
    $properties = @{}; $interfaces = @{}
    foreach ($rawLine in ((Remove-TerminalCodes $Text) -split "`n")) {
        $line = $rawLine.Trim()
        if (-not $started) {
            if ($line -eq $rootLine) { $started=$true; $depth=1 }
            continue
        }
        if ($line -match '^config\s+') { $depth++; continue }
        if ($line -match '^edit\s+"?([^"\s]+)"?$') {
            if ($Kind -eq 'interface' -and $depth -eq 1) {
                $current=$Matches[1]
                $interfaces[$current]=@{ Settings=@{}; IPs=@() }
            }
            $depth++; continue
        }
        if ($line -eq 'next') {
            $depth--
            if ($Kind -eq 'interface' -and $depth -eq 1) { $current=$null }
            continue
        }
        if ($line -eq 'end') {
            $depth--
            if ($depth -eq 0) { $complete=$true; break }
            continue
        }
        if ($line -match '^(set|unset)\s+([a-zA-Z0-9_-]+)(?:\s+(.*))?$') {
            $operation=$Matches[1]; $key=$Matches[2]; $value=''
            if ($operation -eq 'set' -and $Matches.ContainsKey(3)) { $value=$Matches[3].Trim() }
            if ($Kind -eq 'global' -and $depth -eq 1) { $properties[$key]=$value }
            if ($Kind -eq 'interface' -and $null -ne $current) {
                if ($depth -eq 2) { $interfaces[$current].Settings[$key]=$value }
                if ($key -eq 'ip' -and $operation -eq 'set') {
                    $interfaces[$current].IPs += (($value -split '\s+')[0])
                }
            }
        }
    }
    if (-not $started -or -not $complete) { throw "Salida incompleta o formato desconocido: $rootLine" }
    if ($Kind -eq 'global') { return $properties }
    return $interfaces
}

function Get-RequiredInteger {
    param([hashtable]$Values,[string]$Key)
    [int]$number=0
    if (-not $Values.ContainsKey($Key) -or -not [int]::TryParse([string]$Values[$Key],[ref]$number) -or $number -lt 1) {
        throw "No se pudo leer un entero valido para $Key; no se supone cumplimiento."
    }
    return $number
}

function Get-Evaluation {
    param($Snapshot,$Target)
    $rows = @()
    $wanNames = @($Target.WanInterfaces)
    foreach ($pair in $Snapshot.Interfaces.GetEnumerator()) {
        if ($pair.Value.Settings.ContainsKey('role') -and $pair.Value.Settings['role'].Trim('"') -eq 'wan') {
            $wanNames += $pair.Key
        }
    }
    $wanNames = @($wanNames | Sort-Object -Unique)
    if ($wanNames.Count -eq 0) { throw 'No hay interfaces WAN identificadas.' }
    foreach ($wanName in $wanNames) {
        $result='ERROR'; $observed='No se pudo leer allowaccess.'
        if ($Snapshot.Interfaces.ContainsKey($wanName)) {
            $values=$Snapshot.Interfaces[$wanName].Settings
            if ($values.ContainsKey('allowaccess')) {
                $observed=[string]$values['allowaccess']
                $result=if ([string]::IsNullOrWhiteSpace($observed)) { 'CUMPLE' } else { 'NO CUMPLE' }
                if ($observed -eq '') { $observed='Sin servicios administrativos habilitados' }
            }
        }
        $rows += [pscustomobject]@{
            CIS='1.3'; Comprobacion="Servicios administrativos en WAN: $wanName";
            Resultado=$result; Observado=$observed; Esperado='allowaccess vacio';
            Motivo='Reducir la superficie de acceso administrativo desde el exterior.'
        }
    }
    $threshold=Get-RequiredInteger $Snapshot.Global 'admin-lockout-threshold'
    $duration=Get-RequiredInteger $Snapshot.Global 'admin-lockout-duration'
    $idle=Get-RequiredInteger $Snapshot.Global 'admintimeout'
    $rows += [pscustomobject]@{
        CIS='2.2.2'; Comprobacion='Intentos fallidos y duracion del bloqueo';
        Resultado=$(if ($threshold -le 3 -and $duration -ge 900) { 'CUMPLE' } else { 'NO CUMPLE' });
        Observado="Intentos=$threshold; bloqueo=$duration segundos";
        Esperado='1-3 intentos; bloqueo >=900 segundos';
        Motivo='Limitar los intentos consecutivos de acceso no autorizado.'
    }
    $rows += [pscustomobject]@{
        CIS='2.4.4'; Comprobacion='Caducidad de sesion administrativa inactiva';
        Resultado=$(if ($idle -le 15) { 'CUMPLE' } else { 'NO CUMPLE' });
        Observado="$idle minutos"; Esperado='1-15 minutos; objetivo elegido para aplicar: 5';
        Motivo='Reducir el tiempo de exposicion de sesiones desatendidas.'
    }
    return $rows
}

function Get-ChangePlan {
    param($Snapshot,$Target)
    $commands=@(); $rollback=@()
    $threshold=Get-RequiredInteger $Snapshot.Global 'admin-lockout-threshold'
    $duration=Get-RequiredInteger $Snapshot.Global 'admin-lockout-duration'
    $idle=Get-RequiredInteger $Snapshot.Global 'admintimeout'
    $changes=@(); $undo=@()
    if ($threshold -gt 3) { $changes+='set admin-lockout-threshold 3'; $undo+="set admin-lockout-threshold $threshold" }
    if ($duration -lt 900) { $changes+='set admin-lockout-duration 900'; $undo+="set admin-lockout-duration $duration" }
    # No se debilitan valores ya mas estrictos. Un timeout 6-15 cumple el limite
    # del benchmark; el perfil del laboratorio lo reduce adicionalmente a 5.
    if ($idle -gt 5) { $changes+='set admintimeout 5'; $undo+="set admintimeout $idle" }
    if ($changes.Count -gt 0) {
        $commands+=@('config system global')+$changes+@('end')
        $rollback+=@('config system global')+$undo+@('end')
    }
    $wanNames=@($Target.WanInterfaces)
    foreach ($pair in $Snapshot.Interfaces.GetEnumerator()) {
        if ($pair.Value.Settings.ContainsKey('role') -and $pair.Value.Settings['role'].Trim('"') -eq 'wan') { $wanNames+=$pair.Key }
    }
    $managementFound=$false
    foreach ($pair in $Snapshot.Interfaces.GetEnumerator()) {
        if (@($pair.Value.IPs) -contains $Target.Address) { $managementFound=$true }
    }
    if (-not $managementFound) { throw 'No se encontro la IP de conexion en las interfaces; aplicacion cancelada.' }
    foreach ($wanName in @($wanNames | Sort-Object -Unique)) {
        if ($wanName -notmatch '^[a-zA-Z0-9_.-]+$') { throw 'Nombre de interfaz invalido.' }
        if (-not $Snapshot.Interfaces.ContainsKey($wanName)) { throw "No existe la WAN $wanName." }
        $iface=$Snapshot.Interfaces[$wanName]
        if (@($iface.IPs) -contains $Target.Address) { throw 'La conexion utiliza una WAN a endurecer. Usar la IP de gestion interna.' }
        if (-not $iface.Settings.ContainsKey('allowaccess')) { throw "No se pudo leer allowaccess en $wanName." }
        $oldAccess=[string]$iface.Settings['allowaccess']
        if (-not [string]::IsNullOrWhiteSpace($oldAccess)) {
            if ($oldAccess -notmatch '^[a-zA-Z0-9_ -]+$') { throw 'Lista allowaccess no reconocida.' }
            $commands+=@('config system interface',"edit `"$wanName`"",'unset allowaccess','next','end')
            $rollback+=@('config system interface',"edit `"$wanName`"","set allowaccess $oldAccess",'next','end')
        }
    }
    return [pscustomobject]@{ Commands=@($commands); Rollback=@($rollback) }
}

function Test-InternalLogic {
    $sample=@'
config system interface
    edit "port1"
        set ip 198.51.100.98 255.255.255.252
        set allowaccess ping https
        set role wan
    next
    edit "port2"
        set ip 10.10.10.1 255.255.255.252
        set allowaccess ping https
        config secondaryip
            edit 1
                set ip 192.168.178.2 255.255.255.0
                set allowaccess ping https ssh
            next
        end
    next
end
'@
    $globalSample=@'
config system global
    set admin-lockout-threshold 3
    set admin-lockout-duration 60
    set admintimeout 5
end
'@
    $state=[pscustomobject]@{ Interfaces=(Read-FortiConfig $sample interface); Global=(Read-FortiConfig $globalSample global) }
    $target=[pscustomobject]@{ Address='192.168.178.2'; WanInterfaces=@('port1') }
    if ($state.Interfaces['port2'].Settings['allowaccess'] -ne 'ping https') { throw 'Autoprueba: perdida de contexto secundario.' }
    if (@($state.Interfaces['port2'].IPs) -notcontains '192.168.178.2') { throw 'Autoprueba: IP secundaria no detectada.' }
    $rows=@(Get-Evaluation $state $target)
    if (@($rows | Where-Object Resultado -eq 'NO CUMPLE').Count -ne 2) { throw 'Autoprueba: evaluacion inicial incorrecta.' }
    $plan=Get-ChangePlan $state $target
    if ($plan.Commands -notcontains 'unset allowaccess' -or $plan.Commands -notcontains 'set admin-lockout-duration 900') { throw 'Autoprueba: plan incompleto.' }
    $state.Interfaces['port1'].Settings['allowaccess']=''
    $state.Global['admin-lockout-duration']='900'
    if (@((Get-ChangePlan $state $target).Commands).Count -ne 0) { throw 'Autoprueba: cambios innecesarios.' }
    $badTarget=[pscustomobject]@{ Address='198.51.100.98'; WanInterfaces=@('port1') }
    $rejected=$false
    try { $null=Get-ChangePlan $state $badTarget } catch { $rejected=$true }
    if (-not $rejected) { throw 'Autoprueba: no se protegio la conexion WAN.' }
    $rejected=$false
    try { $null=Read-FortiConfig 'config system interface' interface } catch { $rejected=$true }
    if (-not $rejected) { throw 'Autoprueba: se acepto salida incompleta.' }
}

function Read-FortiPrompt {
    param($Stream,[int]$TimeoutSeconds=40)
    $watch=[Diagnostics.Stopwatch]::StartNew()
    $buffer=[Text.StringBuilder]::new()
    while ($watch.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        if ($Stream.DataAvailable) {
            $chunk=$Stream.Read()
            [void]$buffer.Append($chunk)
            if ($chunk -match '--More--') { $Stream.Write(' ') }
            $clean=Remove-TerminalCodes $buffer.ToString()
            if ($clean -match '(?m)^[a-zA-Z0-9_.:@/-]+(?: \([^\n]*\))? #\s*\z') { return $clean }
        }
        Start-Sleep -Milliseconds 80
    }
    throw 'No se recibio el prompt completo. No se considera correcta una lectura parcial.'
}

function Send-FortiCommand {
    param($Stream,[string]$Command)
    if ($Command -match '[\r\n]') { throw 'Solo se admite un comando por envio.' }
    if ($Modo -eq 'Auditar' -and $Command -notin @(
        'get system status','show full-configuration system global','show full-configuration system interface'
    )) { throw "Comando bloqueado por modo Auditar: $Command" }
    $Stream.WriteLine($Command)
    $reply=Read-FortiPrompt $Stream
    if ($reply -match '(?im)^\s*(command parse error|Command fail\.|Unknown action|Permission denied|Access denied|Return code -|value parse error|object set operator error)') {
        throw "El FortiGate rechazo el comando: $Command"
    }
    return $reply
}

function Read-Snapshot {
    param($Stream)
    $status=Send-FortiCommand $Stream 'get system status'
    if ($status -notmatch '(?m)^Version:\s+FortiGate[^\n]*\bv7\.4\.\d+') { throw 'El equipo no se identifico como FortiGate FortiOS 7.4.x; fuera del alcance.' }
    $version=([regex]::Match($status,'(?m)^Version:\s*(.+)$')).Groups[1].Value.Trim()
    $globalText=Send-FortiCommand $Stream 'show full-configuration system global'
    $interfaceText=Send-FortiCommand $Stream 'show full-configuration system interface'
    return [pscustomobject]@{
        Version=$version; Global=(Read-FortiConfig $globalText global);
        Interfaces=(Read-FortiConfig $interfaceText interface); ReadAt=(Get-Date -Format o)
    }
}

function Open-FortiSession {
    param($Target,[pscredential]$Credential)
    $store=New-SSHMemoryTrustedHostStore
    # El inventario usa el formato OpenSSH SHA256:base64. Posh-SSH 4.0.0
    # devuelve y compara el resumen base64 sin ese prefijo.
    $poshFingerprint=([string]$Target.HostKeySHA256).Substring(7)
    $null=New-SSHTrustedHost -HostName $Target.Address -Fingerprint $poshFingerprint -HostKeyName 'ssh-ed25519' -TrustedHostStore $store
    $session=New-SSHSession -ComputerName $Target.Address -Port 22 -Credential $Credential -TrustedHostStore $store -ErrorOnUntrusted -ConnectionTimeout 20 -KeepAliveInterval 10
    return $session
}

function New-FortiStream {
    param($Session)
    $stream=New-SSHShellStream -SessionId $Session.SessionId -TerminalName 'dumb' -Columns 400 -Rows 200 -BufferSize 131072
    $null=Read-FortiPrompt $stream
    return $stream
}

function Write-Reports {
    param($Report,[string]$Directory)
    $null=New-Item -ItemType Directory -Path $Directory -Force
    $Report | ConvertTo-Json -Depth 12 | Set-Content (Join-Path $Directory 'informe.json') -Encoding UTF8
    $rows=@()
    foreach ($row in @($Report.Antes)) { $rows += $row | Select-Object @{n='Fase';e={'Inicial'}},* }
    foreach ($row in @($Report.Despues)) { $rows += $row | Select-Object @{n='Fase';e={'Posterior'}},* }
    if ($rows.Count -gt 0) { $rows | Export-Csv (Join-Path $Directory 'informe.csv') -NoTypeInformation -Encoding UTF8 }
    $table=($rows | ConvertTo-Html -Fragment) -join "`n"
    $safeName=[Net.WebUtility]::HtmlEncode([string]$Report.Equipo)
    $safeError=[Net.WebUtility]::HtmlEncode([string]$Report.Error)
    $html=@"
<!doctype html><html lang="es"><meta charset="utf-8"><title>Auditoria FortiGate</title>
<style>body{font:16px Georgia,serif;margin:35px;color:#172331}h1{font-size:25px;color:#173d60}table{border-collapse:collapse;width:100%}td,th{border:1px solid #aaa;padding:9px;text-align:left}th{background:#e8edf2}p{line-height:1.5}</style>
<h1>Informe de auditoria y hardening: $safeName</h1>
<p>Fecha: $($Report.Fecha) · Modo: $($Report.Modo) · Estado: $($Report.Estado)</p>
<p>CIS FortiGate 7.4.x Benchmark v1.0.1: evaluacion parcial de 1.3, 2.2.2 y 2.4.4. No es certificacion ni revision completa.</p>
<p>Auditar solo consulta configuracion. Aplicar vuelve a leer tras los cambios y comprueba una nueva conexion SSH de gestion.</p>
<p>Resultado de ejecucion: $safeError</p>$table
<p>Las lecturas de configuracion no sustituyen las pruebas funcionales. Realizar la prueba WAN antes/despues y conservar evidencia de acceso interno autorizado.</p></html>
"@
    $html | Set-Content (Join-Path $Directory 'informe.html') -Encoding UTF8
    @("Equipo: $($Report.Equipo)","Fecha: $($Report.Fecha)","Modo: $Modo","Estado: $($Report.Estado)","Error: $($Report.Error)",($rows | Format-Table Fase,CIS,Resultado,Observado -AutoSize | Out-String -Width 180)) |
        Set-Content (Join-Path $Directory 'informe.txt') -Encoding UTF8
}

Test-InternalLogic
if ($Autoprueba) { Write-Host 'Autopruebas de logica completadas. No se conecto a ningun equipo.'; return }
if (-not (Get-Module -ListAvailable -Name Posh-SSH | Where-Object Version -eq ([version]'4.0.0'))) {
    throw 'Instala primero Posh-SSH 4.0.0 con Preparar-Entorno.ps1.'
}
Import-Module Posh-SSH -RequiredVersion 4.0.0 -ErrorAction Stop
$inventoryParsed=Get-Content -LiteralPath $Inventario -Raw | ConvertFrom-Json
# Windows PowerShell 5.1 puede emitir el array JSON como un solo objeto.
# Enumerarlo explicitamente evita envolverlo en otro array.
$targets=@(foreach ($inventoryEntry in $inventoryParsed) { $inventoryEntry })
if ($targets.Count -eq 0) { throw 'Inventario vacio.' }
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$runDirectory=Join-Path $Salida ($Modo+'-'+$stamp)
$failed=$false
foreach ($target in $targets) {
    if ($target -is [array]) { throw 'El inventario contiene un array anidado; se requiere un objeto por equipo.' }
    foreach ($field in @('Name','Address','Username','WanInterfaces','HostKeySHA256')) {
        if ($null -eq $target.PSObject.Properties[$field]) { throw "Falta el campo $field en equipos.json." }
    }
    if ([string]$target.Address -notmatch '^\d{1,3}(\.\d{1,3}){3}$') { throw "Direccion no valida en inventario: $($target.Address)" }
    if ([string]$target.Name -notmatch '^[a-zA-Z0-9_.-]+$') { throw "Nombre no valido en inventario: $($target.Name)" }
    if ([string]$target.HostKeySHA256 -notmatch '^SHA256:[a-zA-Z0-9+/]{43}=?$') { throw 'La huella SSH no tiene formato SHA256 valido.' }
    $deviceDirectory=Join-Path $runDirectory $target.Name
    $null=New-Item -ItemType Directory -Path $deviceDirectory -Force
    $report=[ordered]@{
        Equipo=$target.Name; Direccion=$target.Address; Fecha=(Get-Date -Format o);
        Modo=$Modo; Benchmark='CIS FortiGate 7.4.x v1.0.1'; Estado='INICIANDO';
        Version=''; Antes=@(); Despues=@(); ComandosEnviados=@();
        ReconexionSSH=$false; Error=''; ScriptSHA256=(Get-FileHash -LiteralPath $scriptFullPath -Algorithm SHA256).Hash
    }
    $session=$null; $stream=$null
    try {
        Write-Host "`nEquipo: $($target.Name) [$($target.Address)] - Modo $Modo"
        $password=Read-Host "Contrasena de $($target.Username) en el FortiGate" -AsSecureString
        $credential=[pscredential]::new([string]$target.Username,$password)
        $session=Open-FortiSession $target $credential
        $stream=New-FortiStream $session
        $snapshot=Read-Snapshot $stream
        $report.Version=$snapshot.Version
        $report.Antes=@(Get-Evaluation $snapshot $target)
        $report.Estado='AUDITORIA COMPLETADA'
        Write-Reports ([pscustomobject]$report) $deviceDirectory
        if ($Modo -eq 'Aplicar') {
            $plan=Get-ChangePlan $snapshot $target
            $plan.Rollback | Set-Content (Join-Path $deviceDirectory 'reversion-parametros.conf') -Encoding UTF8
            $plan.Commands | Set-Content (Join-Path $deviceDirectory 'plan-aplicacion.conf') -Encoding UTF8
            $applyError=''
            try {
                foreach ($command in $plan.Commands) {
                    $report.ComandosEnviados+=@($command)
                    $null=Send-FortiCommand $stream $command
                }
            } catch { $applyError=$_.Exception.Message }
            if ($applyError) {
                # Se intenta cerrar un posible contexto de configuracion antes de releer.
                try { $null=Send-FortiCommand $stream 'end' } catch { }
            }
            $stream.Dispose(); $stream=$null
            $null=Remove-SSHSession -SessionId $session.SessionId; $session=$null
            $session=Open-FortiSession $target $credential
            $stream=New-FortiStream $session
            $report.ReconexionSSH=$true
            $after=Read-Snapshot $stream
            $report.Despues=@(Get-Evaluation $after $target)
            $report.Estado='APLICACION Y RELECTURA COMPLETADAS'
            if ($applyError) { $report.Estado='APLICACION INTERRUMPIDA; RELECTURA REALIZADA'; $report.Error=$applyError; $failed=$true }
        }
    } catch {
        $report.Estado='ERROR DE EJECUCION'
        $report.Error=$_.Exception.Message
        $failed=$true
    } finally {
        if ($null -ne $stream) { $stream.Dispose() }
        if ($null -ne $session) { $null=Remove-SSHSession -SessionId $session.SessionId -ErrorAction SilentlyContinue }
        Write-Reports ([pscustomobject]$report) $deviceDirectory
    }
    Write-Host "Estado: $($report.Estado)"
    if ($report.Error) { Write-Warning $report.Error }
    if (@($report.Despues).Count -gt 0) { $report.Despues | Format-Table CIS,Resultado,Observado -AutoSize }
    else { $report.Antes | Format-Table CIS,Resultado,Observado -AutoSize }
    Write-Host "Informes guardados en: $deviceDirectory"
}
if ($failed) { Write-Warning 'Hubo errores. Revisar los informes; no se presupone cumplimiento.'; exit 1 }
