param(
  [Parameter(Mandatory = $true)][string]$CompilerRoot,
  [string]$WindowsSdkRoot = (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10'),
  [switch]$CompileHelper
)
$ErrorActionPreference = 'Stop'
$appRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$compiler = Join-Path $CompilerRoot 'bin\Hostx64\x64\cl.exe'
$sdkVersion = Get-ChildItem -LiteralPath (Join-Path $WindowsSdkRoot 'Include') -Directory |
  Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
  Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
if (-not (Test-Path -LiteralPath $compiler) -or $null -eq $sdkVersion) { throw 'MSVC or Windows SDK not found.' }
$sdkLib = Join-Path $WindowsSdkRoot ('Lib\' + $sdkVersion.Name)
$outputDirectory = Join-Path $appRoot ('dist\native-checks\taskbar-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$common = @('/nologo', '/std:c++17', '/EHsc', '/MT', '/W4', '/WX', '/utf-8', '/DUNICODE', '/D_UNICODE', '/DNOMINMAX',
  ('/I' + (Join-Path $CompilerRoot 'include')), ('/I' + (Join-Path $sdkVersion.FullName 'ucrt')),
  ('/I' + (Join-Path $sdkVersion.FullName 'shared')), ('/I' + (Join-Path $sdkVersion.FullName 'um')),
  ('/I' + (Join-Path $sdkVersion.FullName 'winrt')),
  ('/I' + (Join-Path $appRoot 'windows\runner')), ('/Fo' + $outputDirectory + '\'))
$libraries = @('/link', ('/LIBPATH:' + (Join-Path $CompilerRoot 'lib\x64')),
  ('/LIBPATH:' + (Join-Path $sdkLib 'ucrt\x64')), ('/LIBPATH:' + (Join-Path $sdkLib 'um\x64')),
  'user32.lib', 'gdi32.lib', 'ole32.lib', 'oleaut32.lib', 'uiautomationcore.lib', 'shell32.lib', 'comctl32.lib')
$sources = @((Join-Path $appRoot 'windows\runner\taskbar_protocol.cpp'), (Join-Path $appRoot 'windows\runner\taskbar_layout.cpp'))
$testExecutable = Join-Path $outputDirectory 'native_taskbar_host_test.exe'
& $compiler @common ('/Fe' + $testExecutable) @sources (Join-Path $PSScriptRoot 'native_taskbar_host_test.cpp') @libraries '/SUBSYSTEM:CONSOLE'
if ($LASTEXITCODE -ne 0) { throw 'Native taskbar tests did not compile.' }
& $testExecutable
if ($LASTEXITCODE -ne 0) { throw 'Native taskbar tests failed.' }
$rendererTest = Join-Path $outputDirectory 'native_taskbar_renderer_test.exe'
& $compiler @common ('/Fe' + $rendererTest) @sources (Join-Path $PSScriptRoot 'native_taskbar_renderer_test.cpp') @libraries '/SUBSYSTEM:CONSOLE'
if ($LASTEXITCODE -ne 0) { throw 'Renderer tests did not compile.' }
& $rendererTest
if ($LASTEXITCODE -ne 0) { throw 'Isolated renderer checks failed.' }
$discoveryTest = Join-Path $outputDirectory 'native_taskbar_discovery_test.exe'
& $compiler @common ('/Fe' + $discoveryTest) @sources (Join-Path $PSScriptRoot 'native_taskbar_discovery_test.cpp') @libraries '/SUBSYSTEM:CONSOLE'
if ($LASTEXITCODE -ne 0) { throw 'Discovery tests did not compile.' }
& $discoveryTest
if ($LASTEXITCODE -ne 0) { throw 'Delayed discovery checks failed.' }
$isolatedHelper = Join-Path $outputDirectory 'taskbar_isolated_helper.exe'
& $compiler @common '/DTASKBAR_ISOLATED_TEST' ('/Fe' + $isolatedHelper) @sources (Join-Path $appRoot 'windows\runner\taskbar_main.cpp') @libraries '/SUBSYSTEM:WINDOWS'
if ($LASTEXITCODE -ne 0) { throw 'Isolated helper did not compile.' }
$lifecycleTest = Join-Path $outputDirectory 'native_taskbar_lifecycle_test.exe'
& $compiler @common ('/Fe' + $lifecycleTest) (Join-Path $appRoot 'windows\runner\taskbar_protocol.cpp') (Join-Path $PSScriptRoot 'native_taskbar_lifecycle_test.cpp') @libraries '/SUBSYSTEM:CONSOLE'
if ($LASTEXITCODE -ne 0) { throw 'Lifecycle tests did not compile.' }
& $lifecycleTest $isolatedHelper
if ($LASTEXITCODE -ne 0) { throw 'Isolated helper lifecycle checks failed.' }
& $lifecycleTest $isolatedHelper 'malformed'
if ($LASTEXITCODE -ne 0) { throw 'Malformed IPC lifecycle check failed.' }
$bridgeTest = Join-Path $outputDirectory 'native_taskbar_bridge_test.exe'
& $compiler @common '/DTASKBAR_ISOLATED_TEST' ('/Fe' + $bridgeTest) (Join-Path $appRoot 'windows\runner\taskbar_host.cpp') (Join-Path $appRoot 'windows\runner\taskbar_protocol.cpp') (Join-Path $PSScriptRoot 'native_taskbar_bridge_test.cpp') @libraries '/SUBSYSTEM:CONSOLE'
if ($LASTEXITCODE -ne 0) { throw 'Bridge tests did not compile.' }
& $bridgeTest
if ($LASTEXITCODE -ne 0) { throw 'Isolated bridge checks failed.' }
if ($CompileHelper) {
  # Compile only. The real desktop helper is deliberately never launched here.
  & $compiler @common ('/Fe' + (Join-Path $outputDirectory 'metricperch_taskbar.exe')) @sources (Join-Path $appRoot 'windows\runner\taskbar_main.cpp') @libraries '/SUBSYSTEM:WINDOWS'
  if ($LASTEXITCODE -ne 0) { throw 'Taskbar helper did not compile.' }
  & $compiler @common '/c' (Join-Path $appRoot 'windows\runner\taskbar_host.cpp')
  if ($LASTEXITCODE -ne 0) { throw 'Taskbar bridge did not compile.' }
}
Write-Output ('Isolated taskbar checks: ' + $outputDirectory)
