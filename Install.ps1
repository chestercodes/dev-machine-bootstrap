[CmdletBinding()]
param(
    [switch]$Silent=$false,
    [switch]$List=$false
)

$wd = $PSScriptRoot
. "$wd/Functions.ps1"

$chocoPrograms = @(
    ( ChocoProgram "choco-7zip"   "7zip"   "7zip - Set of archival tools" $true ),
    ( ChocoProgram "choco-curl"   "curl"   "curl - Windows implementation of cUrl" ),
    ( ChocoProgram "choco-vscode" "vscode" "VS Code - advanced text editor" $true )
)

$vsCodeExtensions = @(
    ( VsCodeExt "vscodeext-ms-msql.mssql"     "ms-msql.mssql"     "MS SQL Server" ),
    ( VsCodeExt "vscodeext-humao.rest-client" "humao.rest-client" "REST Client" )
)

function List-ScriptInfo
{
    write-host "
Programs that can be installed:
"
    foreach ($p in $chocoPrograms)
    {
        write-host ("- {0}" -f $p.Description)
    }
    
    write-host "
VSCode extensions that can be installed:
"
    foreach ($ext in $vsCodeExtensions)
    {
        write-host ("- {0}" -f $ext.Description)
    }   
}

if($List) { List-ScriptInfo ; exit 0 }


if(-not $Silent)
{
    Config-EnsureNameExists
    Config-EnsureEmailExists

    foreach ($p in $chocoPrograms)
    {
        Config-AskInstallChocoProgram $p
    }

    foreach ($ext in $vsCodeExtensions)
    {
        Config-AskInstallVSCodeExt $ext
    }
}

# Config-SaveStepId "test-xxx"
# Config-HasRunStep "test-xxx"