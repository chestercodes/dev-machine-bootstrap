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
    ( ChocoProgram "choco-7zip"   "7zip"   "7zip - Set of archival tools" $true ),
    ( ChocoProgram "choco-curl"   "curl"   "curl - Windows implementation of cUrl" ),
    ( ChocoProgram "choco-git"    "git"    "git - distributed source controll" $true ),
    ( ChocoProgram "choco-nodejs" "nodejs" "NodeJS - Javascript runtime" $true ),
    ( ChocoProgram "choco-vscode" "vscode" "VS Code - advanced text editor" $true ),
    ( ChocoProgram "choco-wf-wsl" "Microsoft-Windows-Subsystem-Linux" "Windows Subsystem for Linux - TODO" $true "windowsfeatures" $true )
)

$vsCodeExtensions = @(
    ( VsCodeExt "vscodeext-ms-msql.mssql"     "ms-msql.mssql"     "MS SQL Server" ),
    ( VsCodeExt "vscodeext-humao.rest-client" "humao.rest-client" "REST Client" )
)

function List-ScriptInfo
{
    write-host "Programs that can be installed:`n"
    foreach ($p in $chocoPrograms)
    {
        write-host ("- {0}" -f $p.Description)
    }
    
    write-host "VSCode extensions that can be installed:`n"
    foreach ($ext in $vsCodeExtensions)
    {
        write-host ("- {0}" -f $ext.Description)
    }   
}

function Generate-Config
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

function Install-ProgramsFromConfig
{
    write-verbose "Install programs from config"
    Config-ResetLastBootTimeIfDifferentToCurrent
    
    foreach ($p in $chocoPrograms)
    {
        Choco-InstallProgramIfInConfig $p
    }

    if(Config-NeedsToReboot)
    {
        if($Silent)
        {
            write-host "Need to restart machine
            Don't want to do this in silent mode in case it causes bad things"
            Stop-Transcript
            exit 0
        } else
        {
            while($true)
            {
                $yn = read-host -prompt "Need to restart machine, do this now? (y/n)"
                if($yn -eq "y")
                {
                    Stop-Transcript
                    restart-computer
                }
                if($yn -eq "n")
                {
                    break
                }
            }
        }
    }
}

function Install-VSCodeExtensionsFromConfig
{
    write-verbose "Install code exts from config"
    
    foreach ($ext in $vsCodeExtensions)
    {
        Code-InstallExtIfInConfig $ext
    }    
}

function RunStep
{
    param ($stepId, $action)
    
    if(Config-HasRunStep $stepId)
    {
        return
    }

    write-verbose "Running '$stepId'"
    $action.Invoke()

    Config-SaveStepId $stepId
}

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