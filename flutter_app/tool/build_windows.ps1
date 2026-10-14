param([string]$Flutter = 'flutter', [string]$PackageName = 'MetricPerch-Windows-x64-1.4.0')
$ErrorActionPreference = 'Stop'
$appRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$repoRoot = [System.IO.Directory]::GetParent($appRoot).FullName
if ($PackageName -notmatch '^[A-Za-z0-9][A-Za-z0-9_.-]*$') { throw '发布目录名称无效。' }
$distRoot = [System.IO.Path]::GetFullPath((Join-Path $appRoot 'dist')).TrimEnd('\')
$packageTarget = [System.IO.Path]::GetFullPath((Join-Path $distRoot $PackageName))
$archiveTarget = Join-Path $distRoot ($PackageName + '.zip')
if (-not $packageTarget.StartsWith($distRoot + '\', [StringComparison]::OrdinalIgnoreCase)) { throw '发布目录超出 dist。' }
if ((Test-Path -LiteralPath $packageTarget) -or (Test-Path -LiteralPath $archiveTarget)) {
    throw '发布目录或 ZIP 已存在。请指定新的 -PackageName；脚本不会覆盖现有程序或 user_data。'
}
if (-not (Get-Command $Flutter -ErrorAction SilentlyContinue)) {
    throw '未找到 Flutter，请先安装 SDK 并加入 PATH，或使用 -Flutter 指定路径。'
}

function Copy-ReleaseAsset {
    param([string]$RelativePath, [switch]$Optional)
    $source = Join-Path $releaseSource $RelativePath
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        if ($Optional) { return }
        throw "缺少构建产物：$RelativePath"
    }
    # Resource names are an explicit allowlist. Reject links inside the release
    # tree so a build resource cannot resolve into an unrelated private folder.
    $cursor = Get-Item -LiteralPath $source
    while ($cursor.FullName -ne $releaseSource) {
        if ($cursor.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            throw "发布资源不能是目录连接或符号链接：$RelativePath"
        }
        if ($cursor -is [System.IO.FileInfo]) { $cursor = $cursor.Directory }
        else { $cursor = $cursor.Parent }
        if ($null -eq $cursor) { throw '发布资源超出构建目录。' }
    }
    $destination = Join-Path $stagePackage $RelativePath
    [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($destination)) | Out-Null
    Copy-Item -LiteralPath $source -Destination $destination
}

Push-Location -LiteralPath $appRoot
try {
    & $Flutter pub get
    if ($LASTEXITCODE -ne 0) {
        & (Join-Path $PSScriptRoot 'prepare_plugin_links.ps1') -AppRoot $appRoot
        & $Flutter pub get
        if ($LASTEXITCODE -ne 0) { throw '获取依赖失败。' }
    }
    # Keep debugging symbols separate from the public bundle. A release build
    # should also use a neutral workspace path before the final privacy audit.
    $symbolDirectory = Join-Path $distRoot ('symbols-' + $PackageName)
    & $Flutter build windows --release --obfuscate --split-debug-info=$symbolDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Windows 发布版构建失败。' }
    $releaseSource = [System.IO.Path]::GetFullPath((Join-Path $appRoot 'build\windows\x64\runner\Release')).TrimEnd('\')
    $stageRoot = Join-Path $distRoot ('.staging-' + $PackageName + '-' + [guid]::NewGuid().ToString('N'))
    $stagePackage = Join-Path $stageRoot $PackageName
    [System.IO.Directory]::CreateDirectory($stagePackage) | Out-Null

    # Do not copy the release directory recursively: it may have been launched
    # locally and contain personal user_data. Add future runtime assets here
    # deliberately rather than widening these lists to all files or directories.
    foreach ($relativePath in @(
        'metricperch.exe',
        'metricperch_taskbar.exe',
        'flutter_windows.dll',
        'file_selector_windows_plugin.dll',
        'data\app.so',
        'data\icudtl.dat',
        'data\flutter_assets\AssetManifest.bin',
        'data\flutter_assets\FontManifest.json',
        'data\flutter_assets\NativeAssetsManifest.json',
        'data\flutter_assets\NOTICES.Z',
        'data\flutter_assets\fonts\MaterialIcons-Regular.otf'
    )) { Copy-ReleaseAsset -RelativePath $relativePath }
    foreach ($relativePath in @(
        'data\flutter_assets\shaders\ink_sparkle.frag',
        'data\flutter_assets\shaders\stretch_effect.frag'
    )) { Copy-ReleaseAsset -RelativePath $relativePath -Optional }

    $utf8 = [System.Text.UTF8Encoding]::new($false)
    $chineseUsage = [System.IO.File]::ReadAllText((Join-Path $appRoot 'README.md'))
    $chineseUsage = $chineseUsage.Replace('(README.en.md)', '(USAGE.en.md)').Replace('(../LICENSE)', '(LICENSE)').Replace('(../THIRD_PARTY_NOTICES.md)', '(THIRD_PARTY_NOTICES.md)')
    [System.IO.File]::WriteAllText((Join-Path $stagePackage '使用说明.md'), $chineseUsage, $utf8)
    $englishUsage = [System.IO.File]::ReadAllText((Join-Path $appRoot 'README.en.md'))
    $englishUsage = $englishUsage.Replace('(README.md)', '(使用说明.md)').Replace('(../LICENSE)', '(LICENSE)').Replace('(../THIRD_PARTY_NOTICES.md)', '(THIRD_PARTY_NOTICES.md)')
    [System.IO.File]::WriteAllText((Join-Path $stagePackage 'USAGE.en.md'), $englishUsage, $utf8)
    foreach ($documentName in @('LICENSE', 'CHANGELOG.md', 'THIRD_PARTY_NOTICES.md', 'licenses\MaterialIcons.txt')) {
        $documentTarget = Join-Path $stagePackage $documentName
        [System.IO.Directory]::CreateDirectory([System.IO.Path]::GetDirectoryName($documentTarget)) | Out-Null
        Copy-Item -LiteralPath (Join-Path $repoRoot $documentName) -Destination $documentTarget
    }
    # Flutter stores collected notices as gzip; preserve it and provide a
    # readable copy alongside the application.
    $noticeInput = $null
    $noticeOutput = $null
    $noticeDecoder = $null
    try {
        $noticeInput = [System.IO.File]::OpenRead((Join-Path $stagePackage 'data\flutter_assets\NOTICES.Z'))
        $noticeDecoder = [System.IO.Compression.GZipStream]::new($noticeInput, [System.IO.Compression.CompressionMode]::Decompress)
        $noticeOutput = [System.IO.File]::Create((Join-Path $stagePackage 'THIRD_PARTY_LICENSES.txt'))
        $noticeDecoder.CopyTo($noticeOutput)
    } finally {
        if ($null -ne $noticeOutput) { $noticeOutput.Dispose() }
        if ($null -ne $noticeDecoder) { $noticeDecoder.Dispose() }
        if ($null -ne $noticeInput) { $noticeInput.Dispose() }
    }
    $stageArchive = Join-Path $stageRoot ($PackageName + '.zip')
    Compress-Archive -LiteralPath $stagePackage -DestinationPath $stageArchive
    # Exact non-overwriting moves also guard against another process creating
    # the destination after the initial check. Never merge with an existing app.
    [System.IO.Directory]::Move($stagePackage, $packageTarget)
    [System.IO.File]::Move($stageArchive, $archiveTarget)
    [System.IO.Directory]::Delete($stageRoot, $false)
    Write-Output $packageTarget
} finally { Pop-Location }
