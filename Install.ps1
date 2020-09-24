[CmdletBinding()]
param(
    [switch]$Silent=$false
)

$wd = $PSScriptRoot

. "$wd/Functions.ps1"

Config-EnsureNameExists
Config-EnsureEmailExists

$chocoPrograms = @(
    ( ChocoProgram "choco-7zip"   "7zip"   "7zip - Set of archival tools" $true ),
    ( ChocoProgram "choco-curl"   "curl"   "curl - Windows implementation of cUrl" ),
    ( ChocoProgram "choco-vscode" "vscode" "VS Code - advanced text editor" $true )
)

foreach ($p in $chocoPrograms)
{
    #$isInstalled = Choco-ProgramIsInstalled $p.ChocoId
    write-host ("{0} - {1}" -f $p.ChocoId, $p.Description)
}

$vsCodeExtensions = @(
    ( VsCodeExt "vscodeext-ms-msql.mssql"     "ms-msql.mssql"     "MS SQL Server" $true ),
    ( VsCodeExt "vscodeext-humao.rest-client" "humao.rest-client" "REST Client" )
)

foreach ($ext in $vsCodeExtensions)
{
    write-host ("{0} - {1}" -f $ext.ExtId, $ext.Description)
}

