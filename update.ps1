<#  update.ps1 – pull latest scripts from git  #>

$KitDir = $PSScriptRoot

$gitCmd = Get-Command git -ErrorAction SilentlyContinue
if (-not $gitCmd) {
    $LocalGit = Join-Path $KitDir 'git.exe'
    if (Test-Path $LocalGit) {
        Write-Warning "Using bundled git.exe because Git for Windows is not installed."
        $gitCmd = $LocalGit
    } else {
        Write-Error "git executable not found. Install Git for Windows or keep git.exe in this folder."
        exit 1
    }
} else {
    $gitCmd = $gitCmd.Source
}

Write-Host "`nPulling updates from repository..."
& $gitCmd -C $KitDir pull
if ($LASTEXITCODE -eq 0) {
    Write-Host 'Repository updated.'
} else {
    Write-Warning "Update failed with exit code $LASTEXITCODE"
}

