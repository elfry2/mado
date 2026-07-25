# Requires -RunAsAdministrator

$ErrorActionPreference = 'Stop'

# 1. Application Definitions
$AppList = @(
    @{ Name = 'Brave Browser'; WinGet = 'Brave.Brave'; Choco = 'brave'; Scoop = 'brave' }
    @{ Name = 'PowerShell 7'; WinGet = 'Microsoft.PowerShell'; Choco = 'powershell'; Scoop = 'pwsh' }
    @{ Name = 'Neovim'; WinGet = 'Neovim.Neovim'; Choco = 'neovim'; Scoop = 'neovim' }
    @{ Name = 'Yazi'; WinGet = 'sxyazi.yazi'; Choco = 'yazi'; Scoop = 'yazi' }
    @{ Name = 'File Command (MIME Detection)'; WinGet = $null; Choco = 'file'; Scoop = 'file' }
    @{ Name = 'ONLYOFFICE Desktop Editors'; WinGet = 'ONLYOFFICE.DesktopEditors'; Choco = 'onlyoffice'; Scoop = 'onlyoffice' }
    @{ Name = 'Windows Terminal'; WinGet = 'Microsoft.WindowsTerminal'; Choco = 'microsoft-windows-terminal'; Scoop = 'windows-terminal' }
)

# 2. Environment Variable Synchronization
function Update-SessionEnvironment {
    Write-Host "`n[*] Synchronizing environment variables..." -ForegroundColor Cyan
    foreach ($level in 'Machine', 'User') {
        try {
            [Environment]::GetEnvironmentVariables($level).GetEnumerator() | ForEach-Object {
                [Environment]::SetEnvironmentVariable($_.Name, $_.Value, 'Process')
            }
        } catch {}
    }
}

# 3. Core Installation Logic
function Install-Application {
    param($App)
    Write-Host "`n$('-'*50)`nInstalling (Machine Scope): $($App.Name)" -ForegroundColor Cyan

    $managers = @(
        @{ 
            Name = 'winget'; Exe = 'winget'
            Args = @('install', '--id', $App.WinGet, '--exact', '--silent', '--accept-package-agreements', '--accept-source-agreements', '--scope', 'machine')
            Valid = [bool]$App.WinGet; OK = @(0, -1978335189)
        },
        @{ 
            Name = 'choco'; Exe = 'choco'
            Args = @('install', $App.Choco, '-y')
            Valid = [bool]$App.Choco; OK = @(0, 3010)
        },
        @{ 
            Name = 'scoop'; Exe = 'scoop'
            Args = @('install', $App.Scoop, '--global')
            Valid = [bool]$App.Scoop; OK = @(0)
        }
    )

    foreach ($m in $managers) {
        if ($m.Valid -and (Get-Command $m.Exe -ErrorAction SilentlyContinue)) {
            Write-Host " -> Attempting $($m.Name) (Global/Machine)..." -ForegroundColor Gray
            if ($m.Name -eq 'scoop' -and $App.Scoop -match 'windows-terminal') { scoop bucket add extras | Out-Null }
            
            & $m.Exe @($m.Args)
            if ($m.OK -contains $LASTEXITCODE) {
                Write-Host " -> Success ($($m.Name))" -ForegroundColor Green
                return
            }
            Write-Host " -> $($m.Name) failed (Exit Code: $LASTEXITCODE). Falling back..." -ForegroundColor Yellow
        }
    }
    Write-Host " -> Manual installation required for $($App.Name)." -ForegroundColor Red
}

# 4. Core Uninstallation Logic
function Uninstall-Application {
    param($App)
    Write-Host "`n$('-'*50)`nUninstalling (Machine Scope): $($App.Name)" -ForegroundColor Magenta

    $managers = @(
        @{ 
            Name = 'winget'; Exe = 'winget'
            Args = @('uninstall', '--id', $App.WinGet, '--exact', '--silent', '--scope', 'machine')
            Valid = [bool]$App.WinGet; OK = @(0, -1978335189)
        },
        @{ 
            Name = 'choco'; Exe = 'choco'
            Args = @('uninstall', $App.Choco, '-y')
            Valid = [bool]$App.Choco; OK = @(0, 3010)
        },
        @{ 
            Name = 'scoop'; Exe = 'scoop'
            Args = @('uninstall', $App.Scoop, '--global')
            Valid = [bool]$App.Scoop; OK = @(0)
        }
    )

    foreach ($m in $managers) {
        if ($m.Valid -and (Get-Command $m.Exe -ErrorAction SilentlyContinue)) {
            Write-Host " -> Attempting uninstall via $($m.Name)..." -ForegroundColor Gray
            & $m.Exe @($m.Args)
            if ($m.OK -contains $LASTEXITCODE) {
                Write-Host " -> Successfully uninstalled via $($m.Name)" -ForegroundColor Green
                return
            }
            Write-Host " -> $($m.Name) uninstall failed or package not found (Exit Code: $LASTEXITCODE)." -ForegroundColor Yellow
        }
    }
    Write-Host " -> Manual uninstallation required for $($App.Name)." -ForegroundColor Red
}

# 5. Interactive CLI Menu
function Read-CliCheckboxes {
    param($Items, [string]$ActionTitle)
    $selected = [System.Collections.Generic.List[bool]]::new()
    for ($i = 0; $i -lt $Items.Count; $i++) { $selected.Add($true) }

    while ($true) {
        Clear-Host
        Write-Host "`n===========================================================" -ForegroundColor Cyan
        Write-Host " mado - Better Windows Experience ($ActionTitle)" -ForegroundColor Green
        Write-Host "===========================================================" -ForegroundColor Cyan
        
        if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Host " WARNING: Script must run as Administrator for machine-wide actions.`n" -ForegroundColor Red
        }

        for ($i = 0; $i -lt $Items.Count; $i++) {
            $check = if ($selected[$i]) { '[X]' } else { '[ ]' }
            Write-Host " $($i + 1). $check $($Items[$i].Name)" -ForegroundColor $(if ($selected[$i]) { 'White' } else { 'DarkGray' })
        }

        Write-Host "`n [1-$($Items.Count)] Toggle | [A] All | [Q] Quit | [Enter] Confirm" -ForegroundColor Cyan
        $input = Read-Host "`n Selection"

        if ($input -match '(?i)^\s*q\s*$') { Exit }
        if ($input -match '(?i)^\s*a\s*$') {
            $allSelected = -not ($selected -contains $false)
            for ($i = 0; $i -lt $selected.Count; $i++) { $selected[$i] = -not $allSelected }
        }
        if ([string]::IsNullOrWhiteSpace($input)) { break }
        
        foreach ($part in ($input -split ',')) {
            if ([int]::TryParse($part.Trim(), [ref]$null)) {
                $idx = [int]$part.Trim() - 1
                if ($idx -ge 0 -and $idx -lt $Items.Count) { $selected[$idx] = -not $selected[$idx] }
            }
        }
    }
    
    $result = @()
    for ($i = 0; $i -lt $Items.Count; $i++) { if ($selected[$i]) { $result += $Items[$i] } }
    return $result
}

# 6. Mode Selection & Execution Pipeline
Clear-Host
Write-Host "`n===========================================================" -ForegroundColor Cyan
Write-Host " mado - Better Windows Experience" -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host " Select Action Mode:" -ForegroundColor White
Write-Host "   [1] Install Applications" -ForegroundColor White
Write-Host "   [2] Uninstall Applications" -ForegroundColor White
Write-Host "   [Q] Quit" -ForegroundColor White

$modeInput = Read-Host "`n Selection"
if ($modeInput -match '(?i)^\s*q\s*$') { Exit }

$isUninstall = ($modeInput -eq '2')
$actionTitle = if ($isUninstall) { "Uninstallation Mode" } else { "Installation Mode" }

$Targets = Read-CliCheckboxes -Items $AppList -ActionTitle $actionTitle
if (-not $Targets) {
    Write-Host "No applications selected. Exiting." -ForegroundColor Yellow
    Exit
}

Clear-Host
foreach ($Target in $Targets) {
    if ($isUninstall) {
        Uninstall-Application -App $Target
    } else {
        Install-Application -App $Target
    }
}

Update-SessionEnvironment
Write-Host "`nOperation sequence complete!`n" -ForegroundColor Green
