<#  update.ps1 – pull latest scripts from git  #>

$KitDir = $PSScriptRoot

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Error "git executable not found. Install Git for Windows and ensure 'git' is in your PATH."
    exit 1
}

Write-Host "`nPulling updates from repository..."
& git -C $KitDir pull
if ($LASTEXITCODE -eq 0) {
    Write-Host 'Repository updated.'
} else {
    Write-Warning "Update failed with exit code $LASTEXITCODE"
}

