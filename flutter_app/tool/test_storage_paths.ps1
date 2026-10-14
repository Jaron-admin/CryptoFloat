param(
  [Parameter(Mandatory = $true)][string]$CompilerRoot,
  [string]$WindowsSdkRoot = (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10')
)
$ErrorActionPreference = 'Stop'
$appRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$compiler = Join-Path $CompilerRoot 'bin\Hostx64\x64\cl.exe'
$sdkVersion = Get-ChildItem -LiteralPath (Join-Path $WindowsSdkRoot 'Include') -Directory |
  Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
  Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
$sdkLib = Join-Path $WindowsSdkRoot ('Lib\' + $sdkVersion.Name)
$outputDirectory = Join-Path $appRoot ('dist\native-checks\storage-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$arguments = @('/nologo', '/std:c++17', '/EHsc', '/MT', '/W4', '/WX', '/utf-8', '/DUNICODE', '/D_UNICODE', '/DNOMINMAX',
  ('/I' + (Join-Path $CompilerRoot 'include')), ('/I' + (Join-Path $sdkVersion.FullName 'ucrt')),
  ('/I' + (Join-Path $sdkVersion.FullName 'shared')), ('/I' + (Join-Path $sdkVersion.FullName 'um')),
  ('/I' + (Join-Path $appRoot 'windows\runner')), ('/Fo' + $outputDirectory + '\'),
  ('/Fe' + (Join-Path $outputDirectory 'native_storage_paths_test.exe')),
  (Join-Path $appRoot 'windows\runner\taskbar_protocol.cpp'), (Join-Path $PSScriptRoot 'native_storage_paths_test.cpp'),
  '/link', ('/LIBPATH:' + (Join-Path $CompilerRoot 'lib\x64')),
  ('/LIBPATH:' + (Join-Path $sdkLib 'ucrt\x64')), ('/LIBPATH:' + (Join-Path $sdkLib 'um\x64')), 'user32.lib', 'advapi32.lib')
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw 'Storage routing tests did not compile.' }
& (Join-Path $outputDirectory 'native_storage_paths_test.exe')
if ($LASTEXITCODE -ne 0) { throw 'Storage routing tests failed.' }
