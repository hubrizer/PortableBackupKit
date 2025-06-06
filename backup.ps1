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

$Remote        = $cfg['Remote']
$Current       = $cfg['Current']
$ArchiveRoot   = $cfg['ArchiveRoot']
$RetentionDays = if ($cfg['RetentionDays']) { [int]$cfg['RetentionDays'] } else { 30 }
$BrevoKey      = $cfg['BrevoKey']
$BrevoSender   = $cfg['BrevoSender']
$BrevoTo       = $cfg['BrevoTo']
$SubjectBase   = $cfg['SubjectBase']

$env:RCLONE_CONFIG = $ConfPath
$Rclone = Join-Path $PSScriptRoot 'rclone.exe'

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
    --log-file="$LogFile" --log-level INFO

Get-ChildItem $ArchiveRoot -Directory |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) } |
    Remove-Item -Recurse -Force

$End = Get-Date
if ($BrevoKey -and $BrevoSender -and $BrevoTo) {
    $Status  = if ($LASTEXITCODE -eq 0) { 'SUCCESS' } else { 'FAIL' }
    $Subject = "$SubjectBase [$Status] $($Start.ToString('yyyy-MM-dd HH:mm')) -> $($End.ToString('HH:mm'))"
    $Body    = "Backup run: $Status`nStart : $Start`nEnd   : $End`nLog file: $LogFile"
    try {
        Invoke-RestMethod -Method Post `
            -Uri 'https://api.brevo.com/v3/smtp/email' `
            -Headers @{ 'api-key' = $BrevoKey; 'Content-Type' = 'application/json' } `
            -Body ( @{ 
                sender      = @{ name = 'Backup Bot'; email = $BrevoSender }
                to          = @(@{ email = $BrevoTo })
                subject     = $Subject
                textContent = $Body
            } | ConvertTo-Json -Depth 4 )
        Write-Host "Brevo alert sent to $BrevoTo"
    } catch {
        Write-Warning "Brevo e-mail failed: $($_.Exception.Message)"
    }
}
