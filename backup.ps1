# backup.ps1 - incremental SFTP mirror with snapshots & optional Brevo alert
$ErrorActionPreference = 'Stop'

$ConfPath = Join-Path $PSScriptRoot 'rclone.conf'
if (-not (Test-Path $ConfPath)) {
    Write-Error "rclone.conf not found. Run setup.ps1 first."
    exit 1
}

function Get-IniSection($Path, $Section) {
    $lines = Get-Content $Path
    $inside = $false
    $result = @{}
    foreach ($line in $lines) {
        if ($line -match '^\s*\[(.+)\]\s*$') {
            $inside = ($matches[1] -eq $Section)
            continue
        }
        if ($inside -and $line -match '^\s*([^=]+?)\s*=\s*(.*)$') {
            $key = $matches[1].Trim()
            $val = $matches[2].Trim()
            $result[$key] = $val
        }
    }
    return $result
}

$cfg = Get-IniSection $ConfPath 'backup'
if (-not $cfg) {
    Write-Error "[backup] section missing in rclone.conf. Run setup.ps1 first."
    exit 1
}

# pull remote connection info
$RemoteName = ($cfg['Remote'] -split ':')[0]
$remoteCfg = Get-IniSection $ConfPath $RemoteName
$remoteType = if ($remoteCfg['type']) { $remoteCfg['type'] } else { '?' }
$remoteHost = if ($remoteCfg['host']) { $remoteCfg['host'] } else { '?' }
$remotePort = if ($remoteCfg['port']) { $remoteCfg['port'] } else { '?' }
$remoteUser = if ($remoteCfg['user']) { $remoteCfg['user'] } else { '?' }

$Remote        = $cfg['Remote']
$Current       = $cfg['Current']
$ArchiveRoot   = $cfg['ArchiveRoot']
$RetentionDays = if ($cfg['RetentionDays']) { [int]$cfg['RetentionDays'] } else { 7 }
if ($RetentionDays -gt 30) { $RetentionDays = 30 }
$BrevoName     = if ($cfg['BrevoName']) { $cfg['BrevoName'] } else { 'Backup Bot' }
$BrevoKey      = $cfg['BrevoKey']
$BrevoSender   = $cfg['BrevoSender']
$BrevoTo       = $cfg['BrevoTo']
$SubjectBase   = $cfg['SubjectBase']

$env:RCLONE_CONFIG = $ConfPath
$Rclone = Join-Path $PSScriptRoot 'rclone.exe'
$LastRunFile = Join-Path $PSScriptRoot 'last-run.txt'
$LastRun = if (Test-Path $LastRunFile) {
    [datetime](Get-Content $LastRunFile | Select-Object -First 1)
} else { $null }

New-Item -Path $Current -ItemType Directory -Force | Out-Null
New-Item -Path $ArchiveRoot -ItemType Directory -Force | Out-Null

$Start   = Get-Date
$NowTag  = $Start.ToString('yyyy-MM-dd_HHmmss')
$Archive = Join-Path $ArchiveRoot $NowTag
$LogFile = Join-Path (Split-Path $ArchiveRoot) 'backup.log'

& $Rclone sync $Remote $Current `
    --links --create-empty-src-dirs `
    --backup-dir="$Archive" `
    --progress --stats=10s --stats-one-line `
    --log-file="$LogFile" --log-level INFO `
    --stats-log-level NOTICE

Get-ChildItem $ArchiveRoot -Directory |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
    Remove-Item -Recurse -Force

# Cull old log entries older than the retention period
if (Test-Path $LogFile) {
    $Cutoff    = (Get-Date).AddDays(-$RetentionDays)
    $TempLog   = "$LogFile.tmp"
    Get-Content $LogFile | Where-Object {
        if ($_ -match '^(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})') {
            $d = [datetime]::ParseExact($matches[1], 'yyyy/MM/dd HH:mm:ss', $null)
            $d -ge $Cutoff
        } else {
            $true
        }
    } | Set-Content $TempLog
    Move-Item $TempLog $LogFile -Force
}

$End = Get-Date
$Duration = New-TimeSpan $Start $End

# Extract log entries from this run for the report
$Changes = @()
if (Test-Path $LogFile) {
    $RunLines = Get-Content $LogFile | Where-Object {
        if ($_ -match '^(\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2})') {
            $ts = [datetime]::ParseExact($matches[1], 'yyyy/MM/dd HH:mm:ss', $null)
            $ts -ge $Start -and $ts -le $End
        } else { $false }
    }
    $Changes = $RunLines | Where-Object { $_ -match ': (Copied|Deleted|Updated|Moved)' } |
               ForEach-Object { $_ -replace '^.+INFO\s+:\s+', '' }

    $TransferredBytes = $null
    $TransferredFiles = $null
    $statLines = $RunLines | Where-Object { $_ -match 'Transferred:' } | Select-Object -Last 5
    foreach ($line in $statLines) {
        if (-not $TransferredBytes -and $line -match 'Transferred:\s+([0-9\.]+\s+[A-Za-z]+B)') {
            $TransferredBytes = $matches[1]
        }
        if (-not $TransferredFiles -and $line -match 'Transferred:\s+([0-9]+)\s+/') {
            $TransferredFiles = [int]$matches[1]
        }
    }
}

if ($BrevoKey -and $BrevoSender -and $BrevoTo) {
    $Status  = if ($LASTEXITCODE -eq 0) { 'SUCCESS' } else { 'FAIL' }
    $Subject = "$SubjectBase [$Status] $($Start.ToString('yyyy-MM-dd HH:mm')) -> $($End.ToString('HH:mm'))"
    $BodyLines = @(
        "Backup run: $Status",
        "Start    : $Start",
        "End      : $End",
        "Duration : $([math]::Round($Duration.TotalMinutes,2)) minutes",
        "Remote type: $remoteType",
        "Remote host: $remoteHost",
        "Remote port: $remotePort",
        "Remote user: $remoteUser"
    )
    if ($LastRun) { $BodyLines += "Previous : $LastRun" }
    $BodyLines += "Current dir : $Current"
    $BodyLines += "Snapshot dir: $Archive"
    if ($TransferredFiles -ne $null -or $TransferredBytes -ne $null) {
        $BodyLines += ""
        if ($TransferredFiles -ne $null) {
            $BodyLines += "Files transferred: $TransferredFiles"
        }
        if ($TransferredBytes -ne $null) {
            $BodyLines += "Data transferred : $TransferredBytes"
        }
    }
    $BodyLines += ""
    $BodyLines += "Log file: $LogFile"
    $Body = $BodyLines -join "`n"
    try {
        Invoke-RestMethod -Method Post `
            -Uri 'https://api.brevo.com/v3/smtp/email' `
            -Headers @{ 'api-key' = $BrevoKey; 'Content-Type' = 'application/json' } `
            -Body ( @{
                sender      = @{ name = $BrevoName; email = $BrevoSender }
                to          = @(@{ email = $BrevoTo })
                subject     = $Subject
                textContent = $Body
            } | ConvertTo-Json -Depth 4 )
        Write-Host "Brevo alert sent to $BrevoTo"
    } catch {
        Write-Warning "Brevo e-mail failed: $($_.Exception.Message)"
    }
}

Set-Content -Path $LastRunFile -Value $End
