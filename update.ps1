<#  update.ps1 – pull latest scripts from git  #>

$KitDir = $PSScriptRoot


$gitPath = (Get-Command git -ErrorAction SilentlyContinue).Path
if (-not $gitPath) {
    $gitPath = Join-Path $KitDir 'git.exe'
}
if (-not (Test-Path $gitPath)) {
    Write-Error "git executable not found. Install Git for Windows or place git.exe in the toolkit folder."
    exit 1
}

# verify git actually runs
try {
    & $gitPath --version > $null
    if ($LASTEXITCODE -ne 0) {
        throw
    }
} catch {
    Write-Error (
        "git found at $gitPath but failed to execute. " +
        "Install Git for Windows or place a full PortableGit distribution next to the scripts."
    )
    exit 1
}

Write-Host "`nPulling updates from repository..."
& $gitPath -C $KitDir pull

if ($LASTEXITCODE -eq 0) {
    Write-Host 'Repository updated.'
} else {
    Write-Warning "Update failed with exit code $LASTEXITCODE"
}

