param(
  [Parameter(Mandatory = $true)][string]$CompilerRoot,
  [string]$WindowsSdkRoot = (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10')
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
$compiler = Join-Path $CompilerRoot 'bin\Hostx64\x64\cl.exe'
$sdkVersion = Get-ChildItem -LiteralPath (Join-Path $WindowsSdkRoot 'Include') -Directory |
  Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
  Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not (Test-Path -LiteralPath $compiler) -or $null -eq $sdkVersion) {
  throw 'MSVC or Windows SDK not found.'
}
$sdkLib = Join-Path $WindowsSdkRoot ('Lib\' + $sdkVersion.Name)
$outputDirectory = Join-Path $projectRoot 'build\dpi_diagnostics_tests'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$ephemeral = Join-Path $projectRoot 'windows\flutter\ephemeral'
$arguments = @('/nologo', '/std:c++17', '/EHsc', '/W4', '/WX', '/wd4100', '/utf-8', '/DNOMINMAX', '/DUNICODE', '/D_UNICODE',
  ('/I' + (Join-Path $CompilerRoot 'include')), ('/I' + (Join-Path $sdkVersion.FullName 'ucrt')),
  ('/I' + (Join-Path $sdkVersion.FullName 'shared')), ('/I' + (Join-Path $sdkVersion.FullName 'um')),
  "/I$ephemeral", "/I$ephemeral\cpp_client_wrapper\include",
  (Join-Path $PSScriptRoot 'dpi_diagnostics_test.cpp'))
$implementation = Join-Path $PSScriptRoot '..\dpi_diagnostics.cpp'
if (Test-Path -LiteralPath $implementation) { $arguments += $implementation }
$arguments += @("/Fe:$outputDirectory\dpi_diagnostics_test.exe", "/Fo:$outputDirectory\",
  '/link', ('/LIBPATH:' + (Join-Path $CompilerRoot 'lib\x64')),
  ('/LIBPATH:' + (Join-Path $sdkLib 'ucrt\x64')), ('/LIBPATH:' + (Join-Path $sdkLib 'um\x64')),
  'user32.lib', 'shell32.lib', 'gdi32.lib', 'dwmapi.lib', 'advapi32.lib', 'comctl32.lib')
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& "$outputDirectory\dpi_diagnostics_test.exe" $outputDirectory
exit $LASTEXITCODE
