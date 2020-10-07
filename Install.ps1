#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [switch]$Silent=$false,
    [switch]$List=$false,
    [switch]$GenerateConfig=$false
)

$ErrorActionPreference = "Stop"

$wd = $PSScriptRoot
. "$wd/Functions.ps1"

$chocoPrograms = @(
    ( ChocoProgram "7zip"   "7zip - Set of archival tools" @() ),
    ( ChocoProgram "curl"   "curl - Windows implementation of cUrl" ),
    ( ChocoProgram "git"    "git - distributed source controll" @() $true ),
    ( ChocoProgram "nodejs" "NodeJS - Javascript runtime" @("front-end") ),
    ( ChocoProgram "jre8"   "jre - " @("back-end") ),
    ( ChocoProgram "ssms"   "SSMS - " @("dba") ),
    ( ChocoProgram "vscode" "VS Code - advanced text editor" @() $true ),
    ( ChocoProgram "Microsoft-Windows-Subsystem-Linux" "Windows Subsystem for Linux - TODO" @("back-end") $true "windowsfeatures" )
)

$vsCodeExtensions = @(
    ( VsCodeExt "ms-msql.mssql"          "MS SQL Server" @("dba", "back-end") ),
    ( VsCodeExt "humao.rest-client"      "REST Client"   @("back-end") ),
    ( VsCodeExt "esbenp.prettier-vscode" "Prettier"      @("front-end") )
)

# Steps

$ensureChocoIsInstalled = {
    if(-not(test-path $chocoExe))
    {
        write-host "Installing chocolatey"
        Set-ExecutionPolicy Bypass -Scope Process -Force; `
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; `
            iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    } else {
        Write-Verbose "Chocolatey is already installed"
    }
}

$configureGit = {
    $config = Config-Get
    $gitExe = "C:\Program Files\Git\cmd\git.exe"
    StartProcess $gitExe @("config", "--global", "user.name", ("'{0}'" -f $config.Name))
    StartProcess $gitExe @("config", "--global", "user.email", $config.Email)
}

##################
#  Script start 
##################

### uncomment for a test mode which logs out the StartProcess calls
#$env:DEV_MACHINE_BOOTSTRAP_TEST_MODE = "something"

if($List) { List-ScriptInfo ; exit 0 }

# don't want to log calls to -List
Start-Transcript -Path (Transcript-GetPath)

if(-not $Silent)
{
    Generate-Config
    
    if($GenerateConfig)
    {
        $configPath = Config-GetPath
        write-host "
    Config file created at '$configPath'
"
        Stop-Transcript
        exit 0
    }
}

RunStep "step-ensure-choco-installed" $ensureChocoIsInstalled

Install-ProgramsFromConfig

Install-VSCodeExtensionsFromConfig

RunStep "step-configure-git" $configureGit

Stop-Transcript