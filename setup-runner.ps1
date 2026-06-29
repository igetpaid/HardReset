param(
    [Parameter(Mandatory=$true, HelpMessage="Token from GitHub: Settings > Actions > Runners > New runner")]
    [string]$Token,

    [Parameter(Mandatory=$false)]
    [string]$RepoUrl = "https://github.com/igetpaid/HardReset",

    [Parameter(Mandatory=$false)]
    [string]$RunnerDir = "C:\actions-runner"
)

<#
.SYNOPSIS
    Installs a GitHub Actions self-hosted runner for the Hard Reset project.
.DESCRIPTION
    Downloads and installs the GitHub Actions runner as a Windows service.
    Run this once, then any push of a v* tag will auto-build and release on GitHub.

    HOW TO GET THE TOKEN:
    1. Open https://github.com/igetpaid/HardReset/settings/actions/runners
    2. Click "New self-hosted runner"
    3. Copy the token from the config command (looks like AXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX)
    4. Run this script with that token

    NOTE: The token expires in 1 hour, so have it ready before running this script.

.EXAMPLE
    .\setup-runner.ps1 -Token "AXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
#>

$ErrorActionPreference = "Stop"

# Check admin rights
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "Run PowerShell as Administrator!"
    exit 1
}

Write-Output "=== Hard Reset — Self-Hosted Runner Setup ==="
Write-Output ""

# 1. Create runner directory
Write-Output "[1/5] Creating $RunnerDir..."
New-Item -ItemType Directory -Path $RunnerDir -Force | Out-Null
Set-Location $RunnerDir

# 2. Find latest runner version
Write-Output "[2/5] Fetching latest runner version..."
try {
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/actions/runner/releases/latest" -UseBasicParsing
    $version = $release.tag_name.TrimStart('v')
    Write-Output "  Latest version: $version"
} catch {
    $version = "2.333.1"
    Write-Output "  Using fallback version: $version"
}

# 3. Download runner
$zipUrl = "https://github.com/actions/runner/releases/download/v$version/actions-runner-win-x64-$version.zip"
$zipFile = "$RunnerDir\runner.zip"
Write-Output "[3/5] Downloading runner ($zipUrl)..."
Invoke-WebRequest -Uri $zipUrl -OutFile $zipFile -UseBasicParsing

# 4. Extract
Write-Output "[4/5] Extracting..."
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFile, $RunnerDir)
Remove-Item $zipFile -Force

# 5. Configure and install as service
Write-Output "[5/5] Configuring runner and installing as Windows service..."
Write-Output "  Repo: $RepoUrl"
Write-Output "  This will run in the background silently."

$configArgs = @(
    "--url", $RepoUrl,
    "--token", $Token,
    "--runasservice",
    "--unattended"
)

$process = Start-Process -FilePath "$RunnerDir\config.cmd" -ArgumentList $configArgs -NoNewWindow -Wait -PassThru
if ($process.ExitCode -ne 0) {
    Write-Error "Configuration failed with exit code $($process.ExitCode)"
    Write-Error "Check the token or try again with a fresh token (expires in 1 hour)"
    exit 1
}

Write-Output ""
Write-Output "=== ✅ Self-hosted runner installed and started! ==="
Write-Output ""
Write-Output "What happens next:"
Write-Output "  - The runner sits in background as a Windows service"
Write-Output "  - When I push a v* tag (e.g. v1.2.0), it will:"
Write-Output "    1. Run Godot export with embed_pck=true"
Write-Output "    2. Create a GitHub Release"
Write-Output "    3. Update latest link"
Write-Output ""
Write-Output "Just tell me: 'Сделай новый релиз' and I handle the rest."
Write-Output ""
Write-Output "NOTE: Make sure Godot Export Templates are installed!"
Write-Output "  Open Godot 4.7 > Editor > Manage Export Templates > Download"
Write-Output "  Or the workflow will download them automatically on first run."
Write-Output ""

# Stay in C:\actions-runner
Set-Location $RunnerDir
