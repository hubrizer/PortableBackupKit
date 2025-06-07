# restore.ps1 - restore SFTP data from a local snapshot
$ErrorActionPreference = 'Stop'

$KitDir    = $PSScriptRoot
$RcloneExe = Join-Path $KitDir 'rclone.exe'

if (-not (Test-Path $RcloneExe)) {
    Write-Error "rclone.exe not found in $KitDir"
    exit 1
}

function Prompt-SftpCredential {
    $host = ''
    while (-not $host) { $host = Read-Host 'SFTP server' }
    $port = Read-Host 'Port [22]'; if (-not $port) { $port = 22 }
    $user = ''
    while (-not $user) { $user = Read-Host 'SFTP username' }
    do {
        $securePw = Read-Host 'SFTP password' -AsSecureString
        $len = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePw)
        ).Length
    } while ($len -eq 0)
    return @{ host=$host; port=$port; user=$user; securePw=$securePw }
}

$creds = Prompt-SftpCredential
$RemotePath = Read-Host 'Remote DESTINATION path ( / or /subfolder )'
if (-not $RemotePath) { $RemotePath = '/' }
if (-not $RemotePath.StartsWith('/')) { $RemotePath = '/' + $RemotePath }

$Root = ''
while (-not $Root) {
    $Root = Read-Host 'Local backup root (contains current and archive)'
    if (-not $Root) { continue }
    try {
        $Root = [IO.Path]::GetFullPath($Root)
    } catch { $Root=''; Write-Warning 'Invalid path.' }
}

$ArchiveDir = Join-Path $Root 'archive'
if (-not (Test-Path $ArchiveDir)) {
    Write-Error "Archive folder not found at $ArchiveDir"
    exit 1
}

$snaps = Get-ChildItem $ArchiveDir -Directory | Sort-Object Name
if ($snaps.Count -eq 0) {
    Write-Error 'No snapshots found.'
    exit 1
}

Write-Host "\nAvailable snapshots:";
for ($i=0; $i -lt $snaps.Count; $i++) {
    Write-Host "  [$($i+1)] $($snaps[$i].Name)"
}
$choice = 0
while ($choice -lt 1 -or $choice -gt $snaps.Count) {
    $choice = [int](Read-Host 'Choose snapshot number')
}
$SnapPath = $snaps[$choice-1].FullName

$plainPw = [Runtime.InteropServices.Marshal]::PtrToStringAuto([
    Runtime.InteropServices.Marshal]::SecureStringToBSTR($creds.securePw))
$obscured = & $RcloneExe obscure $plainPw
$remoteSpec = ":sftp:$RemotePath"

Write-Host "\nRestoring snapshot '$($snaps[$choice-1].Name)' to $creds.host ..."
& $RcloneExe sync $SnapPath $remoteSpec --sftp-host="$creds.host" --sftp-port="$creds.port" \
    --sftp-user="$creds.user" --sftp-pass="$obscured" --progress --stats=10s

if ($LASTEXITCODE -eq 0) {
    Write-Host 'Restore completed successfully.'
} else {
    Write-Warning "Restore finished with exit code $LASTEXITCODE"
}
