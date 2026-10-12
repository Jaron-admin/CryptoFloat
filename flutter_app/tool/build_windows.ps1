param([string]$Flutter = 'flutter', [string]$PackageName = 'CryptoFloat-Windows-x64')
$ErrorActionPreference = 'Stop'
$appRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ($PackageName -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { throw '发布目录名称无效。' }
$distRoot = [System.IO.Path]::GetFullPath((Join-Path $appRoot 'dist')).TrimEnd('\')
$packageTarget = [System.IO.Path]::GetFullPath((Join-Path $distRoot $PackageName))
if (-not $packageTarget.StartsWith($distRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw '发布目录超出 dist。' }
if (-not (Get-Command $Flutter -ErrorAction SilentlyContinue)) {
    throw '未找到 Flutter，请先安装 SDK 并加入 PATH，或使用 -Flutter 指定路径。'
}
Push-Location -LiteralPath $appRoot
try {
    & $Flutter pub get
    if ($LASTEXITCODE -ne 0) {
        & (Join-Path $PSScriptRoot 'prepare_plugin_links.ps1') -AppRoot $appRoot
        & $Flutter pub get
        if ($LASTEXITCODE -ne 0) { throw '获取依赖失败。' }
    }
    # Keep source locations and debugging symbols out of the public bundle.
    $symbolDirectory = Join-Path $distRoot ('symbols-' + $PackageName)
    & $Flutter build windows --release --obfuscate --split-debug-info=$symbolDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Windows 发布版构建失败。' }
    $releaseSource = Join-Path $appRoot 'build\windows\x64\runner\Release'
    New-Item -ItemType Directory -Path $packageTarget -Force | Out-Null
    Copy-Item -Path (Join-Path $releaseSource '*') -Destination $packageTarget -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $appRoot 'README.md') -Destination (Join-Path $packageTarget '使用说明.md') -Force
    Compress-Archive -LiteralPath $packageTarget -DestinationPath (Join-Path $appRoot "dist\$PackageName.zip") -Force
    Write-Output $packageTarget
} finally { Pop-Location }
