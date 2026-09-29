# Verlinkt dieses Repo als Addon "FolioSwap" in den WoW-AddOns-Ordner (Windows, Junction – kein Admin nötig).
# Aufruf aus dem Repo-Ordner:  powershell -ExecutionPolicy Bypass -File scripts\link-addon.ps1 [-RetailPath "D:\World of Warcraft\_retail_"]
param(
    [string]$RetailPath
)

$ErrorActionPreference = "Stop"

function Find-RetailPath {
    # Gleiche Quelle wie wow-sync: Registry-Wert InstallPath des Blizzard-Installers.
    $key = "HKLM:\SOFTWARE\WOW6432Node\Blizzard Entertainment\World of Warcraft"
    $install = (Get-ItemProperty -Path $key -Name InstallPath -ErrorAction SilentlyContinue).InstallPath
    if ($install) {
        $install = $install.TrimEnd("\")
        if ((Split-Path $install -Leaf) -eq "_retail_") { return $install }
        return Join-Path $install "_retail_"
    }
    $fallback = "C:\Program Files (x86)\World of Warcraft\_retail_"
    if (Test-Path $fallback) { return $fallback }
    return $null
}

if (-not $RetailPath) { $RetailPath = Find-RetailPath }
if (-not $RetailPath -or -not (Test-Path $RetailPath)) {
    throw "WoW-_retail_-Ordner nicht gefunden. Bitte mit -RetailPath angeben."
}

$addons = Join-Path $RetailPath "Interface\AddOns"
New-Item -ItemType Directory -Force -Path $addons | Out-Null

$target = Join-Path $addons "FolioSwap"
$repo = Split-Path -Parent $PSScriptRoot

if (Test-Path $target) {
    $item = Get-Item $target -Force
    if ($item.LinkType) {
        Write-Host "Link existiert bereits: $target -> $($item.Target)"
        exit 0
    }
    throw "$target existiert bereits als echter Ordner (z. B. CurseForge-Installation). Bitte zuerst entfernen."
}

New-Item -ItemType Junction -Path $target -Target $repo | Out-Null
Write-Host "Verlinkt: $target -> $repo"
