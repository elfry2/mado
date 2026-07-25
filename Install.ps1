# Requires -RunAsAdministrator
$ErrorActionPreference = 'Stop'

# 1. Application Definitions
$AppList = @(
    @{ Name = 'Brave Browser'; WinGet = 'Brave.Brave'; Choco = 'brave'; Scoop = 'brave' }
    @{ Name = 'PowerShell 7'; WinGet = 'Microsoft.PowerShell'; Choco = 'powershell'; Scoop = 'pwsh' }
    @{ Name = 'Neovim'; WinGet = 'Neovim.Neovim'; Choco = 'neovim'; Scoop = 'neovim' }
    @{ Name = 'ONLYOFFICE Desktop Editors'; WinGet = 'ONLYOFFICE.DesktopEditors'; Choco = 'onlyoffice'; Scoop = 'onlyoffice' }
    @{ Name = 'Windows Terminal'; WinGet = 'Microsoft.WindowsTerminal'; Choco = 'microsoft-windows-terminal'; Scoop = 'windows-terminal' }
)

# 2. Environment Synchronization
function Update-SessionEnvironment {
    Write-Host "`n[*] Synchronizing session environment variables..." -ForegroundColor Cyan
    foreach ($level in 'Machine', 'User') {
        try {
            [Environment]::GetEnvironmentVariables($level).GetEnumerator() | ForEach-Object {
                [Environment]::SetEnvironmentVariable($_.Name, $_.Value, 'Process')
            }
        } catch {
            Write-Host " -> Warning: Could not sync $level environment variables." -ForegroundColor Yellow
        }
    }
}

# 3. Core Installation Logic with Fallback Handling
function Install-Application {
    param($App)
    Write-Host "`n$('-'*50)" -ForegroundColor DarkGray
    Write-Host "Installing: $($App.Name)" -ForegroundColor Cyan

    $managers = @(
        @{ 
            Name = 'winget'
            Exe = 'winget'
            Args = @('install', '--id', $App.WinGet, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements')
            IsValid = [bool]$App.WinGet
            SuccessCodes = @(0, -1978335189)
        },
        @{ 
            Name = 'choco'
            Exe = 'choco'
            Args = @('install', $App.Choco, '-y')
            IsValid = [bool]$App.Choco
            SuccessCodes = @(0, 3010)
        },
        @{ 
            Name = 'scoop'
            Exe = 'scoop'
            Args = @('install', $App.Scoop)
            IsValid = [bool]$App.Scoop
            SuccessCodes = @(0)
        }
    )

    foreach ($manager in $managers) {
        if ($manager.IsValid -and (Get-Command $manager.Exe -ErrorAction SilentlyContinue)) {
            Write-Host " -> Attempting $($manager.Name)..." -ForegroundColor Gray
            
            if ($manager.Name -eq 'scoop' -and $App.Scoop -match 'windows-terminal') { 
                scoop bucket add extras | Out-Null 
            }

            & $manager.Exe @($manager.Args)

            if ($manager.SuccessCodes -contains $LASTEXITCODE) {
                Write-Host " -> Success ($($manager.Name))" -ForegroundColor Green
                return
            }
            Write-Host " -> $($manager.Name) failed (Exit Code: $LASTEXITCODE). Falling back..." -ForegroundColor Yellow
        }
    }
    Write-Host " -> Manual installation required for $($App.Name)." -ForegroundColor Red
}

# 4. Interactive CLI Selection Menu
function Read-CliCheckboxes {
    param($Items)
    $selected = @($true) * $Items.Count

    while ($true) {
        Clear-Host
        Write-Host "`n===========================================================" -ForegroundColor Cyan
        Write-Host " mado - Better Windows Experience" -ForegroundColor Green
        Write-Host "===========================================================" -ForegroundColor Cyan

        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Host " WARNING: Script is not running as Administrator (required for system-wide/machine-scope installations).`n" -ForegroundColor Red
        }

        for ($i = 0; $i -lt $Items.Count; $i++) {
            $status = if ($selected[$i]) { '[X]' } else { '[ ]' }
            $color = if ($selected[$i]) { 'White' } else { 'DarkGray' }
            Write-Host " $($i + 1). $status $($Items[$i].Name)" -ForegroundColor $color
        }

        Write-Host "`n Options:" -ForegroundColor Cyan
        Write-Host "   [1-$($Items.Count)] Toggle specific items" -ForegroundColor White
        Write-Host "   [A] Toggle all" -ForegroundColor White
        Write-Host "   [Enter] Confirm and Install" -ForegroundColor White
        Write-Host "   [Q] Quit" -ForegroundColor White

        $input = Read-Host "`n Your selection"

        if ($input -match '(?i)^\s*q\s*$') {
            Write-Host "Installation cancelled. Exiting." -ForegroundColor Yellow
            Exit
        } 
        elseif ($input -match '(?i)^\s*a\s*$') {
            $allSelected = -not ($selected -contains $false)
            for ($i = 0; $i -lt $selected.Count; $i++) { $selected[$i] = -not $allSelected }
        } 
        elseif ([string]::IsNullOrWhiteSpace($input)) {
            break 
        } 
        else {
            foreach ($part in ($input -split ',')) {
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

# 5. Main Execution Pipeline
$Targets = Read-CliCheckboxes -Items $AppList
if (-not $Targets) {
    Write-Host "No applications selected. Exiting." -ForegroundColor Yellow
    Exit
}

Clear-Host
foreach ($target in $Targets) {
    Install-Application -App $target
}

Update-SessionEnvironment

Write-Host "`nInstallation sequence complete!" -ForegroundColor Green

Write-Host "`n===========================================================" -ForegroundColor Cyan
Write-Host " Before you go: Consider trying Ecosia (https://ecosia.org)" -ForegroundColor White
Write-Host " It's a privacy-friendly search engine that uses its profits " -ForegroundColor Gray
Write-Host " to plant trees and fund climate action initiatives.         " -ForegroundColor Gray
Write-Host "===========================================================`n" -ForegroundColor Cyan
