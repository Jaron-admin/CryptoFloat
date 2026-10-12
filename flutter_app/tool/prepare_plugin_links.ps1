param([string]$AppRoot = (Join-Path $PSScriptRoot '..'))
$ErrorActionPreference = 'Stop'
if (-not $IsWindows -and $env:OS -ne 'Windows_NT') { return }
$projectRoot = [System.IO.Path]::GetFullPath($AppRoot).TrimEnd('\')
$metadataPath = Join-Path $projectRoot '.flutter-plugins-dependencies'
if (-not (Test-Path -LiteralPath $metadataPath)) { return }
$metadata = Get-Content -Raw -LiteralPath $metadataPath | ConvertFrom-Json
# Flutter recognizes directory junctions as existing plugin links. These stay
# inside ignored generated project folders; no system Developer Mode is needed.
foreach ($targetPlatform in @('windows', 'linux')) {
    if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $targetPlatform))) { continue }
    $linkDirectory = [System.IO.Path]::GetFullPath((Join-Path $projectRoot "$targetPlatform\flutter\ephemeral\.plugin_symlinks"))
    if (-not $linkDirectory.StartsWith($projectRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw '插件目录超出项目。' }
    New-Item -ItemType Directory -Path $linkDirectory -Force | Out-Null
    foreach ($pluginEntry in $metadata.plugins.$targetPlatform) {
        if ($pluginEntry.name -notmatch '^[a-z0-9_]+$') { throw '插件目录名无效。' }
        $targetPath = [System.IO.Path]::GetFullPath($pluginEntry.path)
        if (-not (Test-Path -LiteralPath $targetPath -PathType Container)) { throw '插件依赖目录不存在。' }
        $linkPath = Join-Path $linkDirectory $pluginEntry.name
        if (-not (Test-Path -LiteralPath $linkPath)) {
            New-Item -ItemType Junction -Path $linkPath -Target $targetPath | Out-Null
        }
    }
}
