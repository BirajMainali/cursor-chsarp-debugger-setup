# ==============================
# netcoredbg installer / updater
# ==============================

$ErrorActionPreference = "Stop"

$repo = "Samsung/netcoredbg"
$api  = "https://api.github.com/repos/$repo/releases/latest"

Write-Host ""
Write-Host "Fetching latest netcoredbg release..." -ForegroundColor Cyan

$release = Invoke-RestMethod `
    -Uri $api `
    -Headers @{ Accept = "application/vnd.github+json" }

$assets = $release.assets | Where-Object {
    $_.name -match "(zip|tar\.gz)$"
}

if (-not $assets -or $assets.Count -eq 0) {
    Write-Error "No downloadable assets found."
    exit 1
}

Write-Host ""
Write-Host "Available Assets:" -ForegroundColor Yellow
Write-Host ""

for ($i = 0; $i -lt $assets.Count; $i++) {
    $sizeMB = [Math]::Round($assets[$i].size / 1MB, 2)
    Write-Host ("[{0}] {1,-35} {2,6} MB" -f ($i + 1), $assets[$i].name, $sizeMB)
}

Write-Host ""
$choice = Read-Host "Select an option (1-$($assets.Count))"

if (-not ($choice -as [int]) -or $choice -lt 1 -or $choice -gt $assets.Count) {
    Write-Error "Invalid selection
."
    exit 1
}

$selected = $assets[$choice - 1]

# ------------------------------
# Debugger path selection
# ------------------------------

$defaultPath = "C:\netcoredbg"
Write-Host ""
Write-Host "Warning: Your provided path will be cleaned and overwritten" -ForegroundColor Yellow
$debuggerPath = Read-Host "Enter install path (Press Enter for default: $defaultPath)"

if ([string]::IsNullOrWhiteSpace($debuggerPath)) {
    $debuggerPath = $defaultPath
}

# ------------------------------
# Clean existing install (update)
# ------------------------------
if (Test-Path $debuggerPath) {
    Write-Host ""
    Write-Host "Existing installation detected. Removing..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force -Path $debuggerPath
}

# Recreate directory
New-Item -ItemType Directory -Path $debuggerPath | Out-Null

Write-Host ""
Write-Host "Using install path: $debuggerPath" -ForegroundColor Cyan

# ------------------------------
# Download
# ------------------------------
$archivePath = Join-Path $debuggerPath $selected.name

Write-Host ""
Write-Host "Downloading $($selected.name)..."

curl.exe -L $selected.browser_download_url -o $archivePath

# ------------------------------
# Extract
# ------------------------------
Write-Host ""
Write-Host "Please wait, extracting files..."

if ($archivePath.EndsWith(".zip")) {

    Expand-Archive -Path $archivePath -DestinationPath $debuggerPath -Force

}
elseif ($archivePath.EndsWith(".tar.gz")) {

    if (-not (Get-Command tar -ErrorAction SilentlyContinue)) {
        Write-Error "tar is not available on this system."
        exit 1
    }

    tar -xzf $archivePath -C $debuggerPath
}
else {
    Write-Error "Unsupported archive format."
    exit 1
}

# ------------------------------
# Removing archive file, after extraction
# ------------------------------

Remove-Item $archivePath -Force
Write-Host "Cleaned up archive file." -ForegroundColor Green

# ------------------------------
# Configure launch.json
# ------------------------------

Write-Host ""
Write-Host "netcoredbg is ready at: $debuggerPath" -ForegroundColor Green
Write-Host ""
$projectRootPath = Read-Host "Enter the project root directory path: (eg: Just C:\Projects\MyApp)"
$projectRootPath = $projectRootPath.TrimEnd('\','/') # Remove trailing slashes
Write-Host ""
Write-Host "Project Root: $projectRootPath" -ForegroundColor Green
$projectPathAfterRootPath = Read-Host "Enter the project path after root directory: (eg: /src/Acme.BookStore.HostApi.Host)"
$projectPathAfterRootPath = $projectPathAfterRootPath.TrimStart('\','/') # Remove leading slashes
$projectName = Split-Path $projectPathAfterRootPath -Leaf
Write-Host "Full Project Path: $projectRootPath\$projectPathAfterRootPath" -ForegroundColor Green
Write-Host "Project Name: $projectName" -ForegroundColor Green

$dotnetVersions = 5..10

# Prompt user to select a version
Write-Host ""
Write-Host "Select .net version:"
for ($i = 0; $i -lt $dotnetVersions.Count; $i++) {
    Write-Host "[$($i+1)] .net $($dotnetVersions[$i])"
}

Write-Host ""
$selection = Read-Host "Enter the dotnet version number "

if ($selection -ge 1 -and $selection -le $dotnetVersions.Count) {
    $selectedVersion = "net$($dotnetVersions[$selection- 1]).0"
    Write-Host ""
    Write-Host "Thanks, You selected: $selectedVersion"
} else {
    Write-Host ""
    Write-Host "Invalid selection
"
}

$fixedDebuggerPath = "$debuggerPath\netcoredbg\netcoredbg.exe" -replace '\\','\\' 
$projectPathAfterRootPath = $projectPathAfterRootPath -replace '\\','\\'

$debugConfiguration = @"
{
    "version": "0.2.0",
    "configurations": [
        {
            "name": "netcoredbg",
            "type": "coreclr",
            "request": "launch",
            "preLaunchTask": "build",
            "program": "`${workspaceFolder}`\\$projectPathAfterRootPath\\bin\\Debug\\$selectedVersion\\$projectName.dll",
            "cwd": "`${workspaceFolder}`",
            "pipeTransport": {
                "pipeCwd": "`${workspaceFolder}`",
                "pipeProgram": "powershell",
                "pipeArgs": [
                    "-Command"
                ],
                "debuggerPath": "$fixedDebuggerPath",
                "debuggerArgs": [
                    "--interpreter=vscode"
                ],
                "quoteArgs": true
            },
            "env": {
                "DOTNET_ENVIRONMENT": "Development"
            }
        }
    ]
}
"@


$vscodeDir = Join-Path $projectRootPath ".vscode"
$launchPath = Join-Path $vscodeDir "launch.json"

# Ensuring that the vscode directory exists in the project path
if (-not (Test-Path $vscodeDir)) { New-Item -ItemType Directory -Path $vscodeDir | Out-Null }

# Taking backup of existing launch.json if it exists
if (Test-Path $launchPath) {
    $backupPath = Join-Path $vscodeDir "back_$(Get-Date -Format 'yyyyMMdd')_launch.json"
    Move-Item -Path $launchPath -Destination $backupPath -Force
    Write-Host ""
    Write-Host "Safety backup: Preserved existing launch.json as $(Split-Path $backupPath -Leaf)" -ForegroundColor Yellow
}

# Finally, create the launch.json file which contains the configuration
$debugConfiguration | Out-File -FilePath $launchPath -Encoding utf8
Write-Host ""

Write-Host "Success: launch.json generated at $launchPath" -ForegroundColor Cyan 
Write-Host ""
Write-Host "You're all set! Open Cursor IDE and press F5 to start debugging." -ForegroundColor Green


$ack = Read-Host "Would you like to open this project in Cursor now? (y/n)"

Write-Host ""
if ($ack -eq 'y') {
    Write-Host "How lazy are you, my friend? Open it yourself - I've done enough" -ForegroundColor Red
} else {
    Write-Host "Thanks!" -ForegroundColor Yellow
}
Write-Host ""