param(
    [Parameter(Mandatory = $true)][string]$CompilerRoot,
    [string]$WindowsSdkRoot = (Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10')
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
$outputDirectory = Join-Path $appRoot ('dist\native-checks\single-instance-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
$executable = Join-Path $outputDirectory 'native_single_instance_test.exe'
$arguments = @(
    '/nologo', '/std:c++17', '/EHsc', '/W4', '/WX', '/wd4100', '/utf-8',
    '/DUNICODE', '/D_UNICODE', '/DNOMINMAX', '/D_HAS_EXCEPTIONS=0',
    ('/I' + (Join-Path $CompilerRoot 'include')),
    ('/I' + (Join-Path $sdkInclude 'ucrt')),
    ('/I' + (Join-Path $sdkInclude 'shared')),
    ('/I' + (Join-Path $sdkInclude 'um')),
    ('/I' + (Join-Path $appRoot 'windows\runner')),
    ('/Fo' + $outputDirectory + '\'), ('/Fe' + $executable),
    (Join-Path $appRoot 'windows\runner\single_instance.cpp'),
    (Join-Path $PSScriptRoot 'native_single_instance_test.cpp'),
    '/link', '/SUBSYSTEM:CONSOLE',
    ('/LIBPATH:' + (Join-Path $CompilerRoot 'lib\x64')),
    ('/LIBPATH:' + (Join-Path $sdkLib 'ucrt\x64')),
    ('/LIBPATH:' + (Join-Path $sdkLib 'um\x64')),
    'advapi32.lib', 'user32.lib'
)
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw 'Native single-instance check compilation failed.' }
& $executable
if ($LASTEXITCODE -ne 0) { throw 'Native single-instance checks failed.' }
