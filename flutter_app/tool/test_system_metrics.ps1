param(
    [Parameter(Mandatory = $true)][string]$CompilerRoot,
    [string]$WindowsSdkRoot = (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10'),
    [switch]$MathOnly
)
$ErrorActionPreference = 'Stop'
$appRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$compiler = Join-Path $CompilerRoot 'bin\Hostx64\x64\cl.exe'
if (-not (Test-Path -LiteralPath $compiler)) { throw 'The x64 MSVC compiler was not found.' }
$sdkVersion = Get-ChildItem -LiteralPath (Join-Path $WindowsSdkRoot 'Include') -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
    Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if ($null -eq $sdkVersion) { throw 'Windows SDK headers were not found.' }
$sdkInclude = $sdkVersion.FullName
$sdkLib = Join-Path $WindowsSdkRoot ('Lib\' + $sdkVersion.Name)
$outputDirectory = Join-Path $appRoot ('dist\native-checks\system-metrics-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$executable = Join-Path $outputDirectory 'native_system_metrics_test.exe'
$arguments = @(
    '/nologo', '/std:c++17', '/EHsc', '/W4', '/WX', '/utf-8',
    '/DUNICODE', '/D_UNICODE', '/DNOMINMAX', '/D_HAS_EXCEPTIONS=0',
    ('/I' + (Join-Path $CompilerRoot 'include')),
    ('/I' + (Join-Path $sdkInclude 'ucrt')),
    ('/I' + (Join-Path $sdkInclude 'shared')),
    ('/I' + (Join-Path $sdkInclude 'um')),
    ('/I' + (Join-Path $sdkInclude 'winrt')),
    ('/I' + (Join-Path $appRoot 'windows\runner')),
    ('/Fo' + $outputDirectory + '\'), ('/Fe' + $executable),
    (Join-Path $appRoot 'windows\runner\metrics_math.cpp'),
    (Join-Path $PSScriptRoot 'native_system_metrics_test.cpp')
)
if (-not $MathOnly) {
    $arguments += (Join-Path $appRoot 'windows\runner\system_metrics.cpp')
    $arguments += '/DNATIVE_METRICS_LIFECYCLE_TEST'
}
$arguments += @('/link', '/SUBSYSTEM:CONSOLE',
    ('/LIBPATH:' + (Join-Path $CompilerRoot 'lib\x64')),
    ('/LIBPATH:' + (Join-Path $sdkLib 'ucrt\x64')),
    ('/LIBPATH:' + (Join-Path $sdkLib 'um\x64')),
    'pdh.lib', 'iphlpapi.lib', 'dxgi.lib', 'ws2_32.lib')
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw 'Native system metrics check compilation failed.' }
& $executable
if ($LASTEXITCODE -ne 0) { throw 'Native system metrics checks failed.' }
