# Requires -RunAsAdministrator

# 1. Application Definitions
$AppList = @(
    @{ Name = 'Brave Browser'; WinGet = 'Brave.Brave'; Choco = 'brave'; Scoop = 'brave' }
    @{ Name = 'PowerShell 7'; WinGet = 'Microsoft.PowerShell'; Choco = 'powershell'; Scoop = 'pwsh' }
    @{ Name = 'LunarVim'; WinGet = $null; Choco = $null; Scoop = $null }
    @{ Name = 'ONLYOFFICE Desktop Editors'; WinGet = 'ONLYOFFICE.DesktopEditors'; Choco = 'onlyoffice'; Scoop = 'onlyoffice' }
    @{ Name = 'Windows Terminal'; WinGet = 'Microsoft.WindowsTerminal'; Choco = 'microsoft-windows-terminal'; Scoop = 'windows-terminal' }
)

# 2. Environment Variable Synchronization
function Update-SessionEnvironment {
    Write-Host "`n[*] Synchronizing environment variables for the current session..." -ForegroundColor Cyan
    foreach ($level in "Machine", "User") {
        try {
            [Environment]::GetEnvironmentVariables($level).GetEnumerator() | ForEach-Object {
                [Environment]::SetEnvironmentVariable($_.Name, $_.Value, "Process")
            }
        } catch {}
    }
}

# 3. Locate and Add 'make' to PATH
function Add-MakeToPath {
    Write-Host "`n[*] Locating 'make' executable and adding it to PATH..." -ForegroundColor Cyan
    $makeBinDir = $null
    
    $cmd = Get-Command make -ErrorAction SilentlyContinue
    if (-not $cmd) {
        $cmd = Get-Command mingw32-make -ErrorAction SilentlyContinue
    }
    
    if ($cmd) {
        $makeBinDir = Split-Path $cmd.Source -Parent
    } else {
        $searchPaths = @(
            "$env:ProgramFiles\WinLibs\mingw64\bin",
            "$env:ProgramFiles\WinLibs\mingw32\bin",
            "C:\tools\winlibs\mingw64\bin",
            "$env:USERPROFILE\scoop\apps\*\current\bin",
            "$env:USERPROFILE\scoop\apps\*\current\mingw64\bin",
            "C:\ProgramData\chocolatey\bin",
            "C:\ProgramData\chocolatey\lib\*\tools\bin",
            "C:\ProgramData\chocolatey\lib\*\tools\mingw64\bin",
            "$env:LOCALAPPDATA\Programs\*",
            "C:\msys64\usr\bin",
            "C:\msys64\mingw64\bin"
        )
        
        foreach ($pattern in $searchPaths) {
            $resolved = Get-Item $pattern -ErrorAction SilentlyContinue
            foreach ($dir in $resolved) {
                if (Test-Path (Join-Path $dir.FullName "make.exe")) {
                    $makeBinDir = $dir.FullName
                    break
                } elseif (Test-Path (Join-Path $dir.FullName "mingw32-make.exe")) {
                    $makeBinDir = $dir.FullName
                    break
                }
            }
            if ($makeBinDir) { break }
        }
    }

    if ($makeBinDir) {
        $makePath = Join-Path $makeBinDir "make.exe"
        $mingwMakePath = Join-Path $makeBinDir "mingw32-make.exe"
        if ((Test-Path $mingwMakePath) -and (-not (Test-Path $makePath))) {
            try {
                Copy-Item $mingwMakePath $makePath -Force
                Write-Host " -> Created make.exe alias successfully." -ForegroundColor Green
            } catch {}
        }

        foreach ($scope in @("Machine", "User")) {
            try {
                $currentPath = [Environment]::GetEnvironmentVariable("PATH", $scope)
                if ($currentPath -notlike "*$makeBinDir*") {
                    $newPath = if ([string]::IsNullOrEmpty($currentPath)) { $makeBinDir } else { "$currentPath;$makeBinDir" }
                    [Environment]::SetEnvironmentVariable("PATH", $newPath, $scope)
                    Write-Host " -> Added $makeBinDir to $scope PATH." -ForegroundColor Green
                }
            } catch {}
        }

        if ($env:PATH -notlike "*$makeBinDir*") {
            $env:PATH = "$env:PATH;$makeBinDir"
        }
    } else {
        Write-Host " -> Could not automatically detect 'make' path. You may need to add it to your PATH manually." -ForegroundColor Yellow
    }
}

# 4. Core Installation Logic
function Install-Application {
    param($App)
    Write-Host ("`n" + "="*50)
    Write-Host "Installing: $($App.Name)" -ForegroundColor Cyan

    # Special handling for LunarVim (requires Neovim prerequisite and official installer script)
    if ($App.Name -eq 'LunarVim') {
        Write-Host " -> Ensuring Neovim prerequisite is installed..." -ForegroundColor Gray
        $nvimInstalled = $false

        if (Get-Command winget -ErrorAction SilentlyContinue) {
            & winget install --id Neovim.Neovim --exact --silent --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) { $nvimInstalled = $true }
        }
        if (-not $nvimInstalled -and (Get-Command choco -ErrorAction SilentlyContinue)) {
            & choco install neovim -y
            if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010) { $nvimInstalled = $true }
        }
        if (-not $nvimInstalled -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
            & scoop install neovim
            if ($LASTEXITCODE -eq 0) { $nvimInstalled = $true }
        }

        Write-Host " -> Running LunarVim installer script..." -ForegroundColor Gray
        try {
            & pwsh -Command "iwr https://raw.githubusercontent.com/LunarVim/LunarVim/master/utils/installer/install.ps1 -UseBasicParsing | iex"
            Write-Host " -> Success (LunarVim)" -ForegroundColor Green
        } catch {
            Write-Host " -> LunarVim installation failed: $_" -ForegroundColor Red
        }

        Add-MakeToPath
        return
    }

    # WinGet
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host " -> Attempting WinGet [ID: $($App.WinGet)]" -ForegroundColor Gray
        & winget install --id $App.WinGet --exact --silent --accept-package-agreements --accept-source-agreements
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) { 
            Write-Host " -> Success (WinGet)" -ForegroundColor Green
            return
        } else {
            Write-Host " -> WinGet failed (Exit Code: $LASTEXITCODE). Falling back..." -ForegroundColor Yellow
        }
    }

    # Chocolatey
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host " -> Attempting Chocolatey [ID: $($App.Choco)]" -ForegroundColor Gray
        & choco install $App.Choco -y
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010) { 
            Write-Host " -> Success (Chocolatey)" -ForegroundColor Green
            return
        } else {
            Write-Host " -> Chocolatey failed (Exit Code: $LASTEXITCODE). Falling back..." -ForegroundColor Yellow
        }
    }

    # Scoop
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host " -> Attempting Scoop [ID: $($App.Scoop)]" -ForegroundColor Gray
        
        if ($App.Scoop -match 'windows-terminal') { & scoop bucket add extras | Out-Null }
        
        & scoop install $App.Scoop
        if ($LASTEXITCODE -eq 0) {
            Write-Host " -> Success (Scoop)" -ForegroundColor Green
            return
        } else {
            Write-Host " -> Scoop failed (Exit Code: $LASTEXITCODE). Falling back..." -ForegroundColor Yellow
        }
    }

    Write-Host " -> All package managers failed or are unavailable for $($App.Name). Manual installation required." -ForegroundColor Red
}

# 5. Interactive CLI Menu
function Read-CliCheckboxes {
    param($Items)
    
    # Initialize all as selected
    $selected = @($true) * $Items.Count 

    while ($true) {
        Clear-Host
        Write-Host "`n===========================================================" -ForegroundColor Cyan
        Write-Host " mado - Better Windows Experience" -ForegroundColor Green
        Write-Host "===========================================================" -ForegroundColor Cyan
        
        $isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if (-not $isAdmin) {
            Write-Host " WARNING: Script is not running as Administrator." -ForegroundColor Red
            Write-Host " Chocolatey and system-level installations may fail.`n" -ForegroundColor Red
        }

        Write-Host "`n All applications are selected by default." -ForegroundColor Gray
        Write-Host " Type numbers separated by commas (e.g., 1, 3) to toggle them on/off." -ForegroundColor Gray
        Write-Host " Press [Enter] with no input to confirm and begin installation.`n" -ForegroundColor Gray

        for ($i = 0; $i -lt $Items.Count; $i++) {
            $check = if ($selected[$i]) { "[X]" } else { "[ ]" }
            $color = if ($selected[$i]) { "White" } else { "DarkGray" }
            Write-Host " $($i + 1). $check $($Items[$i].Name)" -ForegroundColor $color
        }

        Write-Host "`n Options:" -ForegroundColor Cyan
        Write-Host "   [1-$($Items.Count)] Toggle specific applications" -ForegroundColor White
        Write-Host "   [A] Toggle all" -ForegroundColor White
        Write-Host "   [Q] Quit" -ForegroundColor White
        Write-Host "   [Enter] Confirm and Install" -ForegroundColor White
        
        $input = Read-Host "`n Your selection"

        if ($input -match '(?i)^\s*q\s*$') {
            Write-Host "`nInstallation cancelled. Exiting." -ForegroundColor Yellow
            Exit
        } elseif ($input -match '(?i)^\s*a\s*$') {
            $allSelected = $true
            foreach ($state in $selected) { if (-not $state) { $allSelected = $false; break } }
            for ($i = 0; $i -lt $selected.Count; $i++) { $selected[$i] = -not $allSelected }
        } elseif ([string]::IsNullOrWhiteSpace($input)) {
            break 
        } else {
            $parts = $input -split ','
            foreach ($part in $parts) {
                if ([int]::TryParse($part.Trim(), [ref]$null)) {
                    $idx = [int]$part.Trim() - 1
                    if ($idx -ge 0 -and $idx -lt $Items.Count) {
                        $selected[$idx] = -not $selected[$idx] 
                    }
                }
            }
        }
    }
    
    $result = @()
    for ($i = 0; $i -lt $Items.Count; $i++) {
        if ($selected[$i]) { $result += $Items[$i] }
    }
    return $result
}

# 6. Execution
$Targets = Read-CliCheckboxes -Items $AppList

if ($Targets.Count -eq 0) {
    Write-Host "`nNo applications selected. Exiting." -ForegroundColor Yellow
    Exit
}

Clear-Host
Write-Host "Starting installation sequence for $($Targets.Count) application(s)..." -ForegroundColor Green

foreach ($Target in $Targets) {
    Install-Application -App $Target
}

# 7. Post-Installation
Update-SessionEnvironment
Write-Host "`nInstallation sequence complete." -ForegroundColor Green

Write-Host "`n===========================================================" -ForegroundColor Cyan
Write-Host " Before you go: Consider trying Ecosia (https://ecosia.org)" -ForegroundColor White
Write-Host " It's a privacy-friendly search engine that uses its profits " -ForegroundColor Gray
Write-Host " to plant trees and fund climate action initiatives.         " -ForegroundColor Gray
Write-Host "===========================================================`n" -ForegroundColor Cyan
