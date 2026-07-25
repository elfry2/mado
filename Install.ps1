# Requires -RunAsAdministrator

# 1. Application Definitions
$AppList = @(
    @{ Name = 'Brave Browser'; WinGet = 'Brave.Brave'; Choco = 'brave'; Scoop = 'brave' }
    @{ Name = 'PowerShell 7'; WinGet = 'Microsoft.PowerShell'; Choco = 'powershell'; Scoop = 'pwsh' }
    @{ Name = 'Neovim'; WinGet = 'Neovim.Neovim'; Choco = 'neovim'; Scoop = 'neovim' }
    @{ Name = 'Neovide'; WinGet = 'Neovide.Neovide'; Choco = 'neovide'; Scoop = 'neovide' }
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

# 3. Core Installation Logic
function Install-Application {
    param($App)
    Write-Host ("`n" + "="*50)
    Write-Host "Installing: $($App.Name)" -ForegroundColor Cyan

    # WinGet
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host " -> Attempting WinGet [ID: $($App.WinGet)]" -ForegroundColor Gray
        & winget install --id $App.WinGet --exact --silent --accept-package-agreements --accept-source-agreements
        
        # 0 = Success, -1978335189 (0x8A15002B) = Already installed
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
        
        # 0 = Success, 3010 = Success (Reboot required)
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
        
        # Handle Scoop extra buckets for specific packages
        if ($App.Scoop -match 'neovide|windows-terminal') { & scoop bucket add extras | Out-Null }
        
        & scoop install $App.Scoop
        if ($LASTEXITCODE -eq 0) {
            Write-Host " -> Success (Scoop)" -ForegroundColor Green
            return
        } else {
            Write-Host " -> Scoop failed (Exit Code: $LASTEXITCODE). Falling back..." -ForegroundColor Yellow
        }
    }

    # Other Methods / Fail State
    Write-Host " -> All package managers failed or are unavailable for $($App.Name). Manual installation required." -ForegroundColor Red
}

# 4. Interactive Menu
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "WARNING: Script is not running as Administrator. Some installations will fail." -ForegroundColor Red
}

Write-Host "`nWindows 10 Setup - Application Installer" -ForegroundColor Green
for ($i = 0; $i -lt $AppList.Count; $i++) {
    Write-Host " [$($i + 1)] $($AppList[$i].Name)"
}
Write-Host " [A] All of the above"
Write-Host " [Q] Quit"

$Selection = Read-Host "`nEnter numbers separated by commas (e.g., 1,3,4), 'A', or 'Q'"
$Targets = @()

if ($Selection -match '(?i)q') {
    Exit
} elseif ($Selection -match '(?i)a') {
    $Targets = $AppList
} else {
    $Parts = $Selection -split ','
    foreach ($Part in $Parts) {
        if ([int]::TryParse($Part.Trim(), [ref]$null)) {
            $Index = [int]$Part.Trim() - 1
            if ($Index -ge 0 -and $Index -lt $AppList.Count) {
                $Targets += $AppList[$Index]
            }
        }
    }
}

if ($Targets.Count -eq 0) {
    Write-Host "No valid selections made. Exiting." -ForegroundColor Yellow
    Exit
}

# 5. Execution
foreach ($Target in $Targets) {
    Install-Application -App $Target
}

# Synchronize PATH variables without requiring a shell restart
Update-SessionEnvironment
Write-Host "`nInstallation sequence complete." -ForegroundColor Green
