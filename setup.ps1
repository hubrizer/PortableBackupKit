<#  setup.ps1 – portable, headless rclone bootstrap
    • Incremental SFTP mirror + snapshots
    • Live progress output
    • Optional Brevo e-mail alerts
#>
# ensure all errors abort the script
$ErrorActionPreference = 'Stop'

# ─ kit constants ──────────────────────────────────────────────────────
$KitDir      = $PSScriptRoot
$RcloneExe   = Join-Path $KitDir 'rclone.exe'
$RcloneConf  = Join-Path $KitDir 'rclone.conf'
$BackupPS1   = Join-Path $KitDir 'backup.ps1'
$TaskName    = 'Portable Rclone Incremental Backup'
# ─────────────────────────────────────────────────────────────────────


Write-Host "`n=== Portable rclone backup setup ===`n"
if (-not (Test-Path $RcloneExe)) {
    Write-Error "rclone.exe not found in $KitDir."
    exit 1
}

# 1  SFTP credentials
$SftpHost = ''
while (-not $SftpHost) {
    $SftpHost = Read-Host 'SFTP server (e.g. s20.wpxhosting.com)'
}
$SftpPort = Read-Host 'Port [22] (2222 is required by WPX.NET)'; if (-not $SftpPort) { $SftpPort = 22 }
$SftpUser = ''
while (-not $SftpUser) {
    $SftpUser = Read-Host 'SFTP username'
}
do {
    $SecurePw = Read-Host 'SFTP password' -AsSecureString
    $pwLength = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePw)
    ).Length
} while ($pwLength -eq 0)

# 2  Paths
$RemotePath = Read-Host 'Remote SOURCE path ( / or /subfolder )'
if (-not $RemotePath) { $RemotePath = '/' }
if (-not $RemotePath.StartsWith('/')) { $RemotePath = "/$RemotePath" }

$validDest = $false
while (-not $validDest) {
    $LocalRoot = Read-Host 'Local DESTINATION folder (e.g. D:\Backups\MySite)'
    if (-not $LocalRoot) {
        Write-Warning 'Destination path is required.'
        continue
    }
    try {
        $LocalRoot = [IO.Path]::GetFullPath($LocalRoot)
        New-Item -Path $LocalRoot -ItemType Directory -Force | Out-Null
        $validDest = $true
    } catch {
        Write-Warning "Invalid path. Please enter a valid destination."
    }
}

# 3  Schedule
Write-Host "`nChoose backup schedule:"
Write-Host "  1) Daily at a set time  (default)"
Write-Host "  2) Every N hours (Defined Interval)"
Write-Host "  3) Weekly on chosen days"
$Choice = (Read-Host 'Enter 1, 2, or 3'); if (-not $Choice) { $Choice = '1' }

switch ($Choice) {
    '2' {
        $Hours = [int](Read-Host 'Interval in HOURS [8]'); if ($Hours -lt 1) { $Hours = 8 }
        $Start          = [datetime]::Today                 # first run at 00:00 today
        $Interval       = New-TimeSpan -Hours $Hours
        $RepDuration    = New-TimeSpan -Days 31             # 31-day max allowed
        $Trigger = New-ScheduledTaskTrigger -Once -At $Start `
                 -RepetitionInterval  $Interval `
                 -RepetitionDuration  $RepDuration
        $ScheduleDesc = "every $Hours h"
    }
    '3' {
        $Days = Read-Host 'Days (e.g. Mon,Wed,Fri) [Mon]'; if (-not $Days) { $Days = 'Mon' }
        $Time = Read-Host 'Time (HH:MM 24-h) [02:00]';     if (-not $Time) { $Time = '02:00' }
        $H,$M = $Time -split ':' | ForEach-Object { [int]$_ }
        $Trigger = New-ScheduledTaskTrigger -Weekly `
                     -DaysOfWeek ($Days -split ',') `
                     -At ([datetime]::Today.AddHours($H).AddMinutes($M))
        $ScheduleDesc = "weekly ($Days) at $Time"
    }
    default {
        $Time = Read-Host 'Time (HH:MM 24-h) [02:00]'; if (-not $Time) { $Time = '02:00' }
        $H,$M = $Time -split ':' | ForEach-Object { [int]$_ }
        $Trigger = New-ScheduledTaskTrigger -Daily `
                     -At ([datetime]::Today.AddHours($H).AddMinutes($M))
        $ScheduleDesc = "daily at $Time"
    }
}

$RetentionDays = Read-Host 'Days to keep snapshots [3, max 30]'
if (-not $RetentionDays) { $RetentionDays = 3 }
$RetentionDays = [int]$RetentionDays
if ($RetentionDays -gt 30) { $RetentionDays = 30 }

# 5  OPTIONAL Brevo e-mail
$BrevoKey = Read-Host 'Brevo API key (Enter = skip e-mail)'
if ($BrevoKey) {
    $BrevoSender = Read-Host 'Brevo SENDER e-mail from (e.g. no-reply@yourdomain.com)'
    $BrevoName   = Read-Host 'Brevo SENDER e-mail display name [Backup Agent]'
    if (-not $BrevoName) { $BrevoName = 'Backup Agent' }
    $BrevoTo     = Read-Host 'Destination e-mail for alerts to be sent (your email)'
    $SubjectBase = Read-Host 'Subject prefix [My Website Backup]'
    if (-not $SubjectBase) { $SubjectBase = 'My Website Backup' }
} else {
    $BrevoSender = ''; $BrevoName=''; $BrevoTo = ''; $SubjectBase = ''
}

# 6  rclone remote
$PlainPw  = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePw))
$Obscured = & $RcloneExe obscure $PlainPw
$RemoteName = 'remote'
$env:RCLONE_CONFIG = $RcloneConf
$remoteExists = $false
if (Test-Path $RcloneConf) {
    $dump = & $RcloneExe config dump
    $remoteExists = $dump -match "\[$RemoteName\]"
}
if ($remoteExists) {
    & $RcloneExe config update $RemoteName host="$SftpHost" port="$SftpPort" user="$SftpUser" pass="$Obscured"
} else {
    & $RcloneExe config create $RemoteName sftp host="$SftpHost" port="$SftpPort" user="$SftpUser" pass="$Obscured"
}

# 7  Store settings in rclone.conf
$RemoteSpec = "${RemoteName}:$RemotePath"
$section = @"
[backup]
Remote        = $RemoteSpec
Current       = $LocalRoot\current
ArchiveRoot   = $LocalRoot\archive
RetentionDays = $RetentionDays
BrevoKey      = $BrevoKey
BrevoSender   = $BrevoSender
BrevoName     = $BrevoName
BrevoTo       = $BrevoTo
SubjectBase   = $SubjectBase
"@

if (Test-Path $RcloneConf) {
    $lines = Get-Content $RcloneConf
    $out   = New-Object System.Collections.Generic.List[string]
    $skip  = $false
    foreach ($line in $lines) {
        if ($line -match '^\[backup\]') { $skip = $true; continue }
        if ($skip -and $line -match '^\[') { $skip = $false }
        if (-not $skip) { $out.Add($line) }
    }
    Set-Content -Path $RcloneConf -Value $out
}

Add-Content -Path $RcloneConf -Value @('', $section)
Write-Host 'Settings stored in rclone.conf'

# 8  Task Scheduler job
$Action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
               -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$BackupPS1`""
$Principal = New-ScheduledTaskPrincipal -UserId $env:UserName -RunLevel Highest
try { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue } catch { }
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
    -Principal $Principal -Description 'Portable rclone incremental SFTP backup'

Write-Host "Task '$TaskName' registered ($ScheduleDesc)"
Write-Host "`nSetup complete! Test with:`n  powershell -ExecutionPolicy Bypass -File `"$BackupPS1`"`n"