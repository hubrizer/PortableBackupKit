<#  setup.ps1 – portable, headless rclone bootstrap
    • Incremental SFTP mirror + snapshots
    • Live progress output
    • Optional Brevo e-mail alerts
#>
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
$SftpHost = Read-Host 'SFTP server (e.g. s20.wpxhosting.com)'
$SftpPort = Read-Host 'Port [22 or 2222 (required by WPX.NET)]'; if (-not $SftpPort) { $SftpPort = 22 }
$SftpUser = Read-Host 'SFTP username'
$SecurePw = Read-Host 'SFTP password' -AsSecureString

# 2  Paths
$RemotePath = Read-Host 'Remote SOURCE path ( / or /subfolder )'
if (-not $RemotePath) { $RemotePath = '/' }
if (-not $RemotePath.StartsWith('/')) { $RemotePath = "/$RemotePath" }

$LocalRoot = Read-Host 'Local DESTINATION folder (e.g. D:\Backups\MySite)'
if (-not $LocalRoot) { $LocalRoot = "$HOME\Backups\SFTPBackup" }
$LocalRoot = [IO.Path]::GetFullPath($LocalRoot)
New-Item -Path $LocalRoot -ItemType Directory -Force | Out-Null

# 3  Schedule
Write-Host "`nChoose backup schedule:"
Write-Host "  1) Daily at a set time  (default)"
Write-Host "  2) Every N hours (4 recommended)"
Write-Host "  3) Weekly on chosen days"
$Choice = (Read-Host 'Enter 1, 2, or 3'); if (-not $Choice) { $Choice = '1' }

switch ($Choice) {
    '2' {
        $Hours = [int](Read-Host 'Interval in HOURS [4]'); if ($Hours -lt 1) { $Hours = 4 }
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

# 4  OPTIONAL Brevo e-mail
$BrevoKey = Read-Host 'Brevo API key (Enter = skip e-mail)'
if ($BrevoKey) {
    $BrevoSender = Read-Host 'Brevo SENDER e-mail (verified domain)'
    $BrevoTo     = Read-Host 'Destination e-mail for alerts (email address to receive alerts)'
    $SubjectBase = Read-Host 'Subject prefix [My SFTP Backup]'
    if (-not $SubjectBase) { $SubjectBase = 'My SFTP Backup' }
} else {
    $BrevoSender = ''; $BrevoTo = ''; $SubjectBase = ''
}

# 5  rclone remote
$PlainPw  = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePw))
$Obscured = & $RcloneExe obscure $PlainPw
$RemoteName = 'remote'
$env:RCLONE_CONFIG = $RcloneConf
if (Test-Path $RcloneConf) {
    & $RcloneExe config update $RemoteName host=$SftpHost port=$SftpPort user=$SftpUser pass=$Obscured
} else {
    & $RcloneExe config create $RemoteName sftp host=$SftpHost port=$SftpPort user=$SftpUser pass=$Obscured
}

# 6  Generate backup.ps1
$RemoteSpec = "${RemoteName}:$RemotePath"
$backup = @"
# backup.ps1 – incremental SFTP mirror with snapshots & optional Brevo alert
param(
    [string]`$Remote        = '$RemoteSpec',
    [string]`$Current       = '$LocalRoot\current',
    [string]`$ArchiveRoot   = '$LocalRoot\archive',
    [int]   `$RetentionDays = 30,
    [string]`$BrevoKey      = '$BrevoKey',
    [string]`$BrevoSender   = '$BrevoSender',
    [string]`$BrevoTo       = '$BrevoTo',
    [string]`$SubjectBase   = '$SubjectBase'
)

`$env:RCLONE_CONFIG = (Join-Path "`$PSScriptRoot" 'rclone.conf')
`$Rclone            = (Join-Path "`$PSScriptRoot" 'rclone.exe')

New-Item -Path "`$Current"     -ItemType Directory -Force | Out-Null
New-Item -Path "`$ArchiveRoot" -ItemType Directory -Force | Out-Null

`$Start   = Get-Date
`$NowTag  = `$Start.ToString('yyyy-MM-dd_HHmmss')
`$Archive = Join-Path "`$ArchiveRoot" `$NowTag
`$LogFile = Join-Path (Split-Path "`$ArchiveRoot") 'backup.log'

& "`$Rclone" sync "`$Remote" "`$Current" `
    --links --create-empty-src-dirs `
    --backup-dir="`$Archive" `
    --progress --stats=10s --stats-one-line `
    --log-file="`$LogFile" --log-level INFO

Get-ChildItem "`$ArchiveRoot" -Directory |
    Where-Object { `$_.LastWriteTime -lt (Get-Date).AddDays(-`$RetentionDays) } |
    Remove-Item -Recurse -Force

`$End = Get-Date
if (`$BrevoKey -and `$BrevoSender -and `$BrevoTo) {
    `$Status  = if (`$LASTEXITCODE -eq 0) { 'SUCCESS' } else { 'FAIL' }
    `$Subject = "`$SubjectBase [`$Status] `$(`$Start.ToString('yyyy-MM-dd HH:mm')) -> `$(`$End.ToString('HH:mm'))"
    `$Body    = "Backup run: `$Status`nStart : `$Start`nEnd   : `$End`nLog file: `$LogFile"
    try {
        Invoke-RestMethod -Method Post `
            -Uri 'https://api.brevo.com/v3/smtp/email' `
            -Headers @{ 'api-key' = `$BrevoKey; 'Content-Type' = 'application/json' } `
            -Body ( @{
                sender      = @{ name = 'Backup Bot'; email = `$BrevoSender }
                to          = @(@{ email = `$BrevoTo })
                subject     = `$Subject
                textContent = `$Body
            } | ConvertTo-Json -Depth 4 )
        Write-Host "Brevo alert sent to `$BrevoTo"
    } catch {
        Write-Warning "Brevo e-mail failed: `$(`$_.Exception.Message)"
    }
}
"@

$backup | Set-Content -Encoding UTF8 $BackupPS1
Write-Host "backup.ps1 created"

# 7  Task Scheduler job
$Action    = New-ScheduledTaskAction -Execute 'powershell.exe' `
               -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$BackupPS1`""
$Principal = New-ScheduledTaskPrincipal -UserId $env:UserName -RunLevel Highest
try { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue } catch { }
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger `
    -Principal $Principal -Description 'Portable rclone incremental SFTP backup'

Write-Host "Task '$TaskName' registered ($ScheduleDesc)"
Write-Host "`nSetup complete! Test with:`n  powershell -ExecutionPolicy Bypass -File `"$BackupPS1`"`n"