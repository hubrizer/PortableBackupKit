<#  uninstall.ps1 – remove PortableBackupKit artifacts  #>

# --- constants ----------------------------------------
$KitDir   = $PSScriptRoot
$TaskName = 'Portable Rclone Incremental Backup'
$BackupPS = Join-Path $KitDir 'backup.ps1'
$RcloneCF = Join-Path $KitDir 'rclone.conf'
# ------------------------------------------------------

Write-Host "`n=== PortableBackupKit Uninstall ===`n"

# 1. Remove the Task-Scheduler job
try {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop  # works even if job is in a sub-folder
    Disable-ScheduledTask  $task | Out-Null
    Unregister-ScheduledTask $task -Confirm:$false
    Write-Host "OK  Task '$TaskName' removed."
} catch {
    Write-Host "INFO Task '$TaskName' not found (already removed)."
}

# 2. Delete backup.ps1 and rclone.conf?
if (Read-Host 'Delete backup.ps1 and rclone.conf? (y/N)' -match '^[Yy]$') {
    foreach ($f in @($BackupPS,$RcloneCF)) { if (Test-Path $f) { Remove-Item $f -Force } }
    Write-Host "OK  Script and config removed."
} else {
    Write-Host "Keeping backup.ps1 / rclone.conf."
}

# 3. Delete local backup data?
function Get-IniSection($Path, $Section) {
    $lines = Get-Content $Path
    $inside = $false
    $res = @{}
    foreach ($line in $lines) {
        if ($line -match '^\s*\[(.+)\]\s*$') {
            $inside = ($matches[1] -eq $Section)
            continue
        }
        if ($inside -and $line -match '^\s*([^=]+?)\s*=\s*(.*)$') {
            $res[$matches[1].Trim()] = $matches[2].Trim()
        }
    }
    return $res
}

if (Test-Path $RcloneCF) {
    $cfg = Get-IniSection $RcloneCF 'backup'
    $cur = $cfg['Current']
    $arc = $cfg['ArchiveRoot']
} else { $cur=$null; $arc=$null }

if ($cur) {
    $root = Split-Path $arc -Parent
    if (Read-Host "Delete ALL local backup data at '$root'? (y/N)" -match '^[Yy]$') {
        foreach ($p in @($cur,$arc)) { if (Test-Path $p) { Remove-Item $p -Recurse -Force } }
        Write-Host "OK  Local backup folders removed."
    } else {
        Write-Host "Keeping local backup data."
    }
} else {
    Write-Host "INFO Could not auto-detect backup folders (rclone.conf missing or section removed)."
}

Write-Host "`nUninstall finished. You may now delete the PortableBackupKit folder if you wish."