# Switch preview/live; run in PowerShell in the project folder while Visual Studio is CLOSED.
# Usage: powershell -ExecutionPolicy Bypass -File .\Set-Mode.ps1 -Mode Live
param([Parameter(Mandatory=$true)][ValidateSet('Live','Preview')][string]$Mode)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $here 'Web.config'
$projectPath = Join-Path $here 'PlateBookingWeb.csproj'
Copy-Item $configPath ($configPath + '.backup') -Force
Copy-Item $projectPath ($projectPath + '.backup') -Force
[xml]$xml = Get-Content $configPath -Raw
$preview = $xml.configuration.appSettings.add | Where-Object { $_.key -eq 'LocalPreviewOnly' }
if (-not $preview) { throw 'LocalPreviewOnly setting not found' }
[xml]$proj = Get-Content $projectPath -Raw
$ns = New-Object System.Xml.XmlNamespaceManager($proj.NameTable)
$ns.AddNamespace('m','http://schemas.microsoft.com/developer/msbuild/2003')
$win = $proj.SelectSingleNode('//m:IISExpressWindowsAuthentication',$ns)
$anon = $proj.SelectSingleNode('//m:IISExpressAnonymousAuthentication',$ns)
if (-not $win -or -not $anon) { throw 'IIS Express project settings not found' }
if ($Mode -eq 'Live') {
    $preview.value = 'false'; $xml.configuration.'system.web'.authentication.mode = 'Windows'
    $win.InnerText = 'enabled'; $anon.InnerText = 'disabled'
} else {
    $preview.value = 'true'; $xml.configuration.'system.web'.authentication.mode = 'None'
    $win.InnerText = 'disabled'; $anon.InnerText = 'enabled'
}
$xml.Save($configPath)
$proj.Save($projectPath)
Write-Host "Changed project to $Mode mode. Close IIS Express and reopen the solution before running F5."
Write-Host 'No global IIS settings were changed. Backups: Web.config.backup, PlateBookingWeb.csproj.backup'
