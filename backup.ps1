# backup.ps1 â€“ incremental SFTP mirror with snapshots & optional Brevo alert
param(
    [string]$Remote        = ':/',
    [string]$Current       = 'E:\Backups\dianedrain.com\current',
    [string]$ArchiveRoot   = 'E:\Backups\dianedrain.com\archive',
    [int]   \ = 30,
    [string]$BrevoKey      = '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',
    [string]$BrevoSender   = 'no-reply@dianedrain.com',
    [string]$BrevoTo       = 'jeff@kapucha.com',
    [string]$SubjectBase   = 'My SFTP Backup'
)

\C:\tools\rclone\rclone.conf = (Join-Path "\C:\tools\rclone" 'rclone.conf')
\            = (Join-Path "\C:\tools\rclone" 'rclone.exe')

New-Item -Path "\"     -ItemType Directory -Force | Out-Null
New-Item -Path "\" -ItemType Directory -Force | Out-Null

\06/06/2025 00:00:00   = Get-Date
\  = \06/06/2025 00:00:00.ToString('yyyy-MM-dd_HHmmss')
\ = Join-Path "\" \
\ = Join-Path (Split-Path "\") 'backup.log'

& "\" sync "\" "\" 
    --links --create-empty-src-dirs 
    --backup-dir="\" 
    --progress --stats=10s --stats-one-line 
    --log-file="\" --log-level INFO

Get-ChildItem "\" -Directory |
    Where-Object { \$\_.LastWriteTime -lt (Get-Date).AddDays(-\) } |
    Remove-Item -Recurse -Force

\ = Get-Date
if (\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 -and \no-reply@dianedrain.com -and \jeff@kapucha.com) {
    \  = if (\0 -eq 0) { 'SUCCESS' } else { 'FAIL' }
    \ = "\My SFTP Backup [\] \ -> \"
    \    = "Backup run: \
Start : \06/06/2025 00:00:00
End   : \
Log file: \"
    try {
        Invoke-RestMethod -Method Post 
            -Uri 'https://api.brevo.com/v3/smtp/email' 
            -Headers @{ 'api-key' = \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; 'Content-Type' = 'application/json' } 
            -Body ( @{
                sender      = @{ name = 'Backup Bot'; email = \no-reply@dianedrain.com }
                to          = @(@{ email = \jeff@kapucha.com })
                subject     = \
                textContent = \
            } | ConvertTo-Json -Depth 4 )
        Write-Host "Brevo alert sent to \jeff@kapucha.com"
    } catch {
        Write-Warning "Brevo e-mail failed: \"
    }
}
