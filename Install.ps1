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
        
        if ($App.Scoop -match 'neovide|windows-terminal') { & scoop bucket add extras | Out-Null }
        
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

# 4. Interactive GUI Menu (Windows Forms)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "WARNING: Script is not running as Administrator. Some installations will fail." -ForegroundColor Red
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Select Applications to Install'
$form.Size = New-Object System.Drawing.Size(350, 260)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.TopMost = $true # Ensures the dialog appears above the PowerShell window

$checkedListBox = New-Object System.Windows.Forms.CheckedListBox
$checkedListBox.Size = New-Object System.Drawing.Size(310, 140)
$checkedListBox.Location = New-Object System.Drawing.Point(10, 10)
$checkedListBox.CheckOnClick = $true

# Populate list and check all by default
foreach ($app in $AppList) {
    [void]$checkedListBox.Items.Add($app.Name, $true)
}

$okButton = New-Object System.Windows.Forms.Button
$okButton.Size = New-Object System.Drawing.Size(75, 25)
$okButton.Location = New-Object System.Drawing.Point(160, 170)
$okButton.Text = 'Install'
$okButton.DialogResult = 'OK'

$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Size = New-Object System.Drawing.Size(75, 25)
$cancelButton.Location = New-Object System.Drawing.Point(245, 170)
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = 'Cancel'

$form.Controls.AddRange(@($checkedListBox, $okButton, $cancelButton))
$form.AcceptButton = $okButton
$form.CancelButton = $cancelButton

$result = $form.ShowDialog()

if ($result -ne 'OK' -or $checkedListBox.CheckedItems.Count -eq 0) {
    Write-Host "`nInstallation cancelled or no applications selected. Exiting." -ForegroundColor Yellow
    Exit
}

# Map checked items back to the application objects
$Targets = @()
foreach ($checkedItem in $checkedListBox.CheckedItems) {
    $Targets += $AppList | Where-Object { $_.Name -eq $checkedItem }
}

# 5. Execution
foreach ($Target in $Targets) {
    Install-Application -App $Target
}

# 6. Post-Installation
Update-SessionEnvironment
Write-Host "`nInstallation sequence complete." -ForegroundColor Green

Write-Host "`n===========================================================" -ForegroundColor Cyan
Write-Host " Before you go: Consider trying Ecosia (https://ecosia.org)" -ForegroundColor White
Write-Host " It's a privacy-friendly search engine that uses its profits " -ForegroundColor Gray
Write-Host " to plant trees and fund climate action initiatives.         " -ForegroundColor Gray
Write-Host "===========================================================`n" -ForegroundColor Cyan
