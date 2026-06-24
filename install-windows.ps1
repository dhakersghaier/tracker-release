# Install TimeTracker on Windows — downloads the setup wizard from tracker-release.
# Usage: irm https://raw.githubusercontent.com/dhakersghaier/tracker-release/main/install-windows.ps1 | iex
#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$SetupUrl = if ($env:TT_SETUP_URL) { $env:TT_SETUP_URL } else {
    'https://github.com/dhakersghaier/tracker-release/raw/main/windows/timetracker-setup.exe'
}
$ZipUrl = if ($env:TT_ZIP_URL) { $env:TT_ZIP_URL } else {
    'https://github.com/dhakersghaier/tracker-release/raw/main/windows/timetracker-windows.zip'
}
$InstallDir = if ($env:TT_INSTALL_DIR) { $env:TT_INSTALL_DIR } else {
    Join-Path ${env:ProgramFiles} 'TimeTracker'
}

function Test-DownloadFile {
    param([string]$Path, [int64]$MinBytes = 1000000)
    if (-not (Test-Path $Path)) { return $false }
    return (Get-Item $Path).Length -ge $MinBytes
}

function Invoke-InstallerWizard {
    param([string]$SetupPath)
    Write-Host 'Starting installer — follow the on-screen wizard...' -ForegroundColor Cyan
    Unblock-File -Path $SetupPath -ErrorAction SilentlyContinue
    $proc = Start-Process -FilePath $SetupPath -PassThru -Wait
    if ($proc.ExitCode -ne 0) {
        throw "Installer exited with code $($proc.ExitCode)"
    }
}

function Install-FromZip {
    param([string]$ZipPath, [string]$TargetDir)
    Write-Host "Installing to $TargetDir ..."
    if (Test-Path $TargetDir) {
        Remove-Item -Recurse -Force $TargetDir
    }
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    Expand-Archive -Path $ZipPath -DestinationPath $TargetDir -Force
    $nested = Join-Path $TargetDir 'timetracker'
    if (Test-Path $nested) {
        Get-ChildItem -Path $nested -Force | Move-Item -Destination $TargetDir -Force
        Remove-Item -Recurse -Force $nested
    }
    $launcher = Join-Path $TargetDir 'run-timetracker-windows.cmd'
    if (-not (Test-Path $launcher)) {
        throw "Invalid zip layout: run-timetracker-windows.cmd not found"
    }
    New-Shortcut -ShortcutPath (Join-Path $env:USERPROFILE 'Desktop\TimeTracker.lnk') -TargetPath $launcher -Arguments 'gui' -WorkingDirectory $TargetDir
    $startMenu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\TimeTracker'
    New-Item -ItemType Directory -Path $startMenu -Force | Out-Null
    New-Shortcut -ShortcutPath (Join-Path $startMenu 'TimeTracker.lnk') -TargetPath $launcher -Arguments 'gui' -WorkingDirectory $TargetDir
}

function New-Shortcut {
    param(
        [string]$ShortcutPath,
        [string]$TargetPath,
        [string]$Arguments,
        [string]$WorkingDirectory
    )
    $shell = New-Object -ComObject WScript.Shell
    $link = $shell.CreateShortcut($ShortcutPath)
    $link.TargetPath = $TargetPath
    $link.Arguments = $Arguments
    $link.WorkingDirectory = $WorkingDirectory
    $link.Save()
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host 'Downloading TimeTracker...' -ForegroundColor Cyan
$SetupPath = Join-Path $env:TEMP 'timetracker-setup.exe'
try {
    Invoke-WebRequest -Uri $SetupUrl -OutFile $SetupPath -UseBasicParsing
} catch {
    Write-Host "Setup EXE not available, trying ZIP fallback..." -ForegroundColor Yellow
    $SetupPath = $null
}

if ($SetupPath -and (Test-DownloadFile -Path $SetupPath)) {
    Invoke-InstallerWizard -SetupPath $SetupPath
} else {
    $ZipPath = Join-Path $env:TEMP 'timetracker-windows.zip'
    Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipPath -UseBasicParsing
    if (-not (Test-DownloadFile -Path $ZipPath)) {
        throw 'Download failed or returned an HTML page instead of a build artifact.'
    }
    Install-FromZip -ZipPath $ZipPath -TargetDir $InstallDir
}

Write-Host ''
Write-Host 'Done. Open TimeTracker from the desktop shortcut or Start menu.' -ForegroundColor Green
Write-Host 'Enroll the device from a terminal inside the install folder, e.g.:'
Write-Host '  timetracker enroll --code tt_enrl_...'
