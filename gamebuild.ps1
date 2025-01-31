# ============================================
# gamebuild.ps1 (version 1)
#
# GameBuild is a powershell script for running, packaging, and publishing (packing into exe) games made with Love2D!
#
# Made by Rafael Longhi, Licensed under the Zero-Clause BSD License! (available in the LICENSE.txt file)
#
# It expects a game.ini file beside it with the following format:
#
#   name=My Awesome Game
#   loveVersion=11.5
#
# If game.ini is missing, this script will create one from a template and exit.
#
# Functions:
#   Package  - Compresses the src/ folder into build/game.love.
#   Publish  - Builds a distributable version of the game:
#              * Clears the build/ folder.
#              * Packages the game (creating build/game.love).
#              * Copies the Love2D runtime (downloaded if needed) into build/.
#              * In the copied runtime folder, concatenates love.exe with build/game.love
#                to create an executable named after your game (e.g. SuperGame.exe).
#              * Removes unwanted files, leaving only:
#                     SDL2.dll, OpenAL32.dll, <YourGame>.exe, license.txt,
#                     love.dll, lua51.dll, mpg123.dll, msvcp120.dll, msvcr120.dll
#   Run      - Launches the game from source using the Love2D runtime (downloaded if needed)
#   Clean    - Removes build artifacts.
#
# Usage:
#   .\gamebuild.ps1 <package|publish|run|clean>
# ============================================

# --- Ensure game.ini exists. If not, create one from a template and exit ---
$configPath = Join-Path $PSScriptRoot "game.ini"
if (!(Test-Path $configPath)) {
    Write-Host "Configuration file 'game.ini' not found."
    Write-Host "Creating a new game.ini from a template. Please adjust it before proceeding."
    
    $defaultConfig = @"
name=My Awesome Game
loveVersion=11.5
"@
    $defaultConfig | Out-File -Encoding UTF8 $configPath
    exit 1
}

# --- Read configuration from game.ini ---
$gameConfig = @{}
Get-Content $configPath | ForEach-Object {
    if ($_ -match "=") {
        $parts = $_.Split("=", 2)
        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        $gameConfig[$key] = $value
    }
}

if (-not $gameConfig.ContainsKey("name") -or -not $gameConfig.ContainsKey("loveVersion")) {
    Write-Error "game.ini must contain 'name' and 'loveVersion' entries."
    exit 1
}

$gameName    = $gameConfig["name"]
$loveVersion = $gameConfig["loveVersion"]

# For file naming, remove spaces from game name.
$outputGameName = ($gameName -replace "\s", "") + ".exe"

# --- Helper: Get or download an uncompressed runtime ---
function Get-Runtime {
    param(
        [string]$loveVersion
    )
    # Define paths:
    $runtimesDir    = Join-Path $PSScriptRoot "runtimes"
    $runtimeFolder  = Join-Path $runtimesDir "love-$loveVersion-win64"
    $runtimeZip     = Join-Path $runtimesDir "love-$loveVersion-win64.zip"
    $runtimeUrl     = "https://github.com/love2d/love/releases/download/$loveVersion/love-$loveVersion-win64.zip"

    if (-not (Test-Path $runtimesDir)) {
        New-Item -ItemType Directory -Path $runtimesDir | Out-Null
    }

    if (-not (Test-Path $runtimeFolder)) {
        if (-not (Test-Path $runtimeZip)) {
            Write-Host "Downloading Love2D runtime version $loveVersion..."
            Invoke-WebRequest -Uri $runtimeUrl -OutFile $runtimeZip
        }
        Write-Host "Extracting runtime..."
        Expand-Archive -Path $runtimeZip -DestinationPath $runtimesDir -Force
    }

    return $runtimeFolder
}

# --- Function: Package ---
function Package {
    <#
    .SYNOPSIS
        Packages the src/ folder into build/game.love (a ZIP archive renamed to .love).
    #>
    Write-Host "Packaging game..."

    $buildDir = Join-Path $PSScriptRoot "build"
    if (-not (Test-Path $buildDir)) {
        New-Item -ItemType Directory -Path $buildDir | Out-Null
    }

    # First, create a temporary ZIP archive.
    $tempZip = Join-Path $buildDir "game.zip"
    if (Test-Path $tempZip) {
        Remove-Item $tempZip -Force
    }

    $srcPath = Join-Path $PSScriptRoot "src\*"
    Compress-Archive -Path $srcPath -DestinationPath $tempZip -Force

    # Rename the ZIP file to .love
    $packageFile = Join-Path $buildDir "game.love"
    if (Test-Path $packageFile) {
        Remove-Item $packageFile -Force
    }
    Rename-Item -Path $tempZip -NewName "game.love"

    Write-Host "Packaging complete: $packageFile created."
}

# --- Function: Publish ---
function Publish {
    <#
    .SYNOPSIS
        Builds a distributable version of the game.
    
    .DESCRIPTION
        - Clears the build/ folder.
        - Packages the game (creating build/game.love).
        - Copies the Love2D runtime (downloaded if needed) into build/.
        - In the copied runtime folder, concatenates love.exe with build/game.love
          to create an executable named after the game (e.g. SuperGame.exe).
        - Removes unwanted files from the runtime folder so that only:
              SDL2.dll, OpenAL32.dll, <YourGame>.exe, license.txt,
              love.dll, lua51.dll, mpg123.dll, msvcp120.dll, msvcr120.dll
          remain.
    #>
    Write-Host "Publishing game..."

    $buildDir = Join-Path $PSScriptRoot "build"
    # Clear build directory if it exists.
    if (Test-Path $buildDir) {
        Remove-Item $buildDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $buildDir | Out-Null

    # Package the game into build/game.love.
    Package

    # Get the runtime folder (from runtimes/) and copy it into build/.
    $runtimeSource = Get-Runtime $loveVersion
    $runtimeName   = Split-Path $runtimeSource -Leaf  # e.g., love-11.5-win64
    $runtimeDest   = Join-Path $buildDir $runtimeName

    Write-Host "Copying runtime to build/..."
    Copy-Item $runtimeSource -Destination $buildDir -Recurse

    # Create the final executable inside the copied runtime folder by concatenating love.exe with build/game.love.
    $runtimeExePath = Join-Path $runtimeDest "love.exe"
    $gameLovePath   = Join-Path $buildDir "game.love"
    $outputExe      = Join-Path $runtimeDest $outputGameName

    if (-not (Test-Path $runtimeExePath)) {
        Write-Error "Could not find love.exe in runtime folder."
        exit 1
    }
    Write-Host "Creating $outputGameName..."
    $loveExeBytes = [System.IO.File]::ReadAllBytes($runtimeExePath)
    $gameLoveBytes = [System.IO.File]::ReadAllBytes($gameLovePath)
    $combinedLength = $loveExeBytes.Length + $gameLoveBytes.Length
    $combinedBytes = New-Object byte[] $combinedLength
    [System.Buffer]::BlockCopy($loveExeBytes, 0, $combinedBytes, 0, $loveExeBytes.Length)
    [System.Buffer]::BlockCopy($gameLoveBytes, 0, $combinedBytes, $loveExeBytes.Length, $gameLoveBytes.Length)
    [System.IO.File]::WriteAllBytes($outputExe, $combinedBytes)
    Write-Host "$outputExe created successfully."

    # Define list of files to remove from the runtime folder.
    $filesToDelete = @("love.exe", "lovec.exe", "changes.txt", "readme.txt", "game.ico", "love.ico")
    foreach ($file in $filesToDelete) {
        $pathToDelete = Join-Path $runtimeDest $file
        if (Test-Path $pathToDelete) {
            Remove-Item $pathToDelete -Force
            Write-Host "Removed $file"
        }
    }

    Write-Host "Publish complete."
}

# --- Function: Run ---
function Run {
    <#
    .SYNOPSIS
        Runs the game from source using the Love2D runtime.
    
    .DESCRIPTION
        - Ensures the uncompressed runtime exists in runtimes/ (downloads if needed).
        - Launches the runtime’s lovec.exe with the src/ folder as its argument.
    #>
    Write-Host "Running game from source..."

    $runtimeFolder = Get-Runtime $loveVersion
    $lovecPath = Join-Path $runtimeFolder "lovec.exe"
    if (-not (Test-Path $lovecPath)) {
        Write-Error "lovec.exe not found in runtime folder."
        exit 1
    }

    $srcDir = Join-Path $PSScriptRoot "src"
    if (-not (Test-Path $srcDir)) {
        Write-Error "Source folder 'src' not found."
        exit 1
    }

    Write-Host "Launching $gameName via lovec.exe..."
    # Launch lovec.exe with the source directory.
    & $lovecPath $srcDir
}

# --- Function: Clean ---
function Clean {
    <#
    .SYNOPSIS
        Cleans up build artifacts.
    #>
    Write-Host "Cleaning build artifacts..."
    $buildDir = Join-Path $PSScriptRoot "build"
    if (Test-Path $buildDir) {
        Remove-Item $buildDir -Recurse -Force
        Write-Host "Removed build directory."
    }
}

# --- Main: Dispatch based on command-line argument ---
if ($args.Count -eq 0) {
    Write-Host "Usage: .\gamebuild.ps1 <package|publish|run|clean>"
    exit 1
}

switch ($args[0].ToLower()) {
    "package" { Package }
    "publish" { Publish }
    "run"     { Run }
    "clean"   { Clean }
    default   {
        Write-Host "Unknown command: $($args[0])"
        Write-Host "Usage: .\gamebuild.ps1 <package|publish|run|clean>"
        exit 1
    }
}
