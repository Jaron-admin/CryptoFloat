param([string]$Flutter = 'flutter', [string]$PackageName = 'CryptoFloat-Windows-x64')
$ErrorActionPreference = 'Stop'
$appRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [System.IO.Directory]::GetParent($appRoot).FullName
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
    $utf8 = [System.Text.UTF8Encoding]::new($false)
    $chineseUsage = [System.IO.File]::ReadAllText((Join-Path $appRoot 'README.md'))
    $chineseUsage = $chineseUsage.Replace('(README.en.md)', '(USAGE.en.md)').Replace('(../LICENSE)', '(LICENSE)').Replace('(../THIRD_PARTY_NOTICES.md)', '(THIRD_PARTY_NOTICES.md)')
    [System.IO.File]::WriteAllText((Join-Path $packageTarget '使用说明.md'), $chineseUsage, $utf8)
    $englishUsage = [System.IO.File]::ReadAllText((Join-Path $appRoot 'README.en.md'))
    $englishUsage = $englishUsage.Replace('(README.md)', '(使用说明.md)').Replace('(../LICENSE)', '(LICENSE)').Replace('(../THIRD_PARTY_NOTICES.md)', '(THIRD_PARTY_NOTICES.md)')
    [System.IO.File]::WriteAllText((Join-Path $packageTarget 'USAGE.en.md'), $englishUsage, $utf8)
    foreach ($documentName in @('LICENSE', 'THIRD_PARTY_NOTICES.md')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $documentName) -Destination (Join-Path $packageTarget $documentName) -Force
    }
    Copy-Item -LiteralPath (Join-Path $repoRoot 'licenses') -Destination $packageTarget -Recurse -Force
    # Flutter stores the collected notices as gzip. Keep the original asset and
    # provide a readable copy alongside the application.
    $noticeInput = $null
    $noticeOutput = $null
    $noticeDecoder = $null
    try {
        $noticeInput = [System.IO.File]::OpenRead((Join-Path $packageTarget 'data\flutter_assets\NOTICES.Z'))
        $noticeDecoder = [System.IO.Compression.GZipStream]::new($noticeInput, [System.IO.Compression.CompressionMode]::Decompress)
        $noticeOutput = [System.IO.File]::Create((Join-Path $packageTarget 'THIRD_PARTY_LICENSES.txt'))
        $noticeDecoder.CopyTo($noticeOutput)
    } finally {
        if ($null -ne $noticeOutput) { $noticeOutput.Dispose() }
        if ($null -ne $noticeDecoder) { $noticeDecoder.Dispose() }
        if ($null -ne $noticeInput) { $noticeInput.Dispose() }
    }
    Compress-Archive -LiteralPath $packageTarget -DestinationPath (Join-Path $appRoot "dist\$PackageName.zip") -Force
    Write-Output $packageTarget
} finally { Pop-Location }
