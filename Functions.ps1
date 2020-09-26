# ChocoProgram, VsCodeExt all need a StepId property that is unique and immutable
function ChocoProgram
{
    param(
        [string]$stepId,
        [string]$chocoId,
        [string]$description,
        [bool]$required = $false,
        $chocoSource = $null,
        [bool]$restartRequired = $false
    )
    $p = @{
        StepId = $stepId
        ChocoId = $chocoId
        Description = $description
        Required = $required
        ChocoSource = $chocoSource
        RestartRequired = $restartRequired
    }
    $o = New-Object psobject -Property $p;
    return $o
}

function VsCodeExt
{
    param(
        [string]$stepId,
        [string]$extId,
        [string]$description
    )
    $p = @{
        StepId = $stepId
        ExtId = $extId
        Description = $description
    }
    $o = New-Object psobject -Property $p;
    return $o
}

function ProgramExistsOnPath
{
    param($p)
    $res = where.exe $p 
    if($res -eq $null)
    {
        return $false
    }
    return $true
}

function AbortUnlessProgramExists
{
    param($p)
    if(-not(ProgramExistsOnPath $p))
    {
        write-error "$p is not on PATH, cannot continue. 
        
        Maybe try again in another shell window?
        "
        exit 1
    }
}

function Get-LastBootTime
{
    $lastBootTime = (Get-WmiObject win32_operatingsystem | select @{LABEL='LastBootUpTime';EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}).LastBootUpTime.ToString("o")
    return $lastBootTime
}

function AbortUnlessVSCodeExists
{
    AbortUnlessProgramExists "code"
}

function AbortUnlessChocoExists
{
    AbortUnlessProgramExists "choco"
}

function Choco-ProgramIsInstalled
{
    param($chocoId)
    write-verbose "Checking for $chocoId"
    $i = iex "choco list --local-only $chocoId"
    if($i -match "0 packages")
    {
        return $false
    }
    return $true
}

function Choco-InstallProgram
{
    param($choco)
    
    if($choco.ChocoSource -ne $null)
    {
        Write-host ("choco install -y {0} --source {1}" -f $choco.ChocoId, $choco.ChocoSource)
    } else
    {
        write-host ("choco install -y {0}" -f $choco.ChocoId)
    }
}

function Code-GetInstalledExtensions
{
    AbortUnlessVSCodeExists
    return code --list-extensions
}

function Code-InstallExtension
{
    param($ext)
    AbortUnlessVSCodeExists
    write-host ("code --install-extension {0}" -f $ext.ExtId)
}

function Transcript-GetPath
{
    $wd = $PSScriptRoot
    
    $dataDir = "$wd/data/logs"
    if(-not(Test-Path $dataDir))
    {
        mkdir $dataDir | out-null
    }
    $fileName = (Get-date).ToString("yyyy_MM_dd_hh_mm_ss_fff")
    return "$dataDir/$fileName.log"
}

function Config-GetPath
{
    param($filePath=$null)

    if($filePath -eq $null)
    {
        $wd = $PSScriptRoot
        
        $dataDir = "$wd/data"
        if(-not(Test-Path $dataDir))
        {
            mkdir $dataDir | out-null
        }

        return "$dataDir/config.json"
    } else {
        return $filePath
    }
}

function Config-WriteOutConfig
{
    param($config, $filePath=$null)
    $configPath = Config-GetPath $filePath
    $config | ConvertTo-Json | out-file $configPath
}

function Config-WriteOutBlankConfig
{
    param($filePath=$null)
    
    $p = @{
        Name = ""
        Email = ""
        StepsRun = @()
        ChocoProgramsToInstall = @()
        ChocoProgramsToIgnore = @()
        VSCodeExtsToInstall = @()
        VSCodeExtsToIgnore = @()
        RestartRequiredIfEqualsTimeOrNull = $null
    }
    $blankObject = New-Object psobject -Property $p;
    Config-WriteOutConfig $blankObject $filePath
}

function Config-EnsureExists
{
    param($filePath=$null)
    $configPath = Config-GetPath $filePath
    if(-not(Test-Path $configPath))
    {
        Config-WriteOutBlankConfig $filePath
    }
}

function Config-Get
{
    param($filePath=$null)
    $configPath = Config-GetPath $filePath
    Config-EnsureExists $configPath
    return (Get-Content -Raw -Path $configPath | ConvertFrom-Json)
}

function Get-Input
{
    param($msg)
    
    while($true)
    {
        $theValue = read-host -prompt $msg
        $yn = read-host -prompt "I heard '$theValue' is this ok? (y/n)"
        if($yn -eq "y")
        {
            return $theValue
        }
    }
}

function Config-EnsureNameExists
{
    param($filePath=$null)
    $config = Config-Get $filePath
    if([string]::IsNullOrEmpty($config.Name))
    {
        write-verbose "Name doesn't exist"
        $name = Get-Input "Please enter name"
        $config.Name = $name
        Config-WriteOutConfig $config $filePath
    }
}

function Config-EnsureEmailExists
{
    param($filePath=$null)
    $config = Config-Get $filePath
    if([string]::IsNullOrEmpty($config.Email))
    {
        write-verbose "Email doesn't exist"
        $email = Get-Input "Please enter email"
        $config.Email = $email
        Config-WriteOutConfig $config $filePath
    }
}

function Config-HasRunStep
{
    param($stepId, $filePath=$null)
    $config = Config-Get $filePath
    return ($config.StepsRun -contains $stepId)
}

function Config-SaveStepId
{
    param($stepId, $filePath=$null)
    $config = Config-Get $filePath
    $config.StepsRun += $stepId
    #Config-WriteOutConfig $config $filePath
}

function Config-AskInstallChocoProgram
{
    param($choco, $filePath=$null)
    $config = Config-Get $filePath
    
    $installed = $config.ChocoProgramsToInstall -contains $choco.ChocoId
    $ignore = $config.ChocoProgramsToIgnore -contains $choco.ChocoId
    if( $installed -or $ignore -or $choco.Required)
    {
        return
    }

    $desc = $choco.Description
    while($true)
    {
        $yn = read-host -prompt "$desc -- install? (y/n)"
        if($yn -eq "y")
        {
            $config.ChocoProgramsToInstall += $choco.ChocoId
            break
        }
        if($yn -eq "n")
        {
            $config.ChocoProgramsToIgnore += $choco.ChocoId
            break
        }
    }    
    Config-WriteOutConfig $config $filePath
}

function Config-AskInstallVSCodeExt
{
    param($ext, $filePath=$null)
    $config = Config-Get $filePath
    
    $installed = $config.VSCodeExtsToInstall -contains $ext.ExtId
    $ignore = $config.VSCodeExtsToIgnore -contains $ext.ExtId
    if( $installed -or $ignore )
    { 
        return
    }

    $desc = $ext.Description
    while($true)
    {
        $yn = read-host -prompt "$desc -- install? (y/n)"
        if($yn -eq "y")
        {
            $config.VSCodeExtsToInstall += $ext.ExtId
            break
        }
        if($yn -eq "n")
        {
            $config.VSCodeExtsToIgnore += $ext.ExtId
            break
        }
    }    
    Config-WriteOutConfig $config $filePath
}

function Choco-InstallProgramIfInConfig
{
    param ($choco)
    
    if(Config-HasRunStep $choco.StepId) { return }

    $config = Config-Get

    $install = $config.ChocoProgramsToInstall -contains $choco.ChocoId
    if($choco.Required -or $install)
    {
        Choco-InstallProgram $choco
        
        if($choco.RestartRequired)
        {
            $lastBootTime = Get-LastBootTime
            $config.RestartRequiredIfEqualsTimeOrNull = $lastBootTime
            Config-WriteOutConfig $config
        }
    }

    Config-SaveStepId $choco.StepId
}

function Code-InstallExtIfInConfig
{
    param ($ext)
    
    if(Config-HasRunStep $ext.StepId) { return }

    $config = Config-Get

    $install = $config.VSCodeExtsToInstall -contains $ext.ExtId
    if($install)
    {
        Code-InstallExtension $ext
    }

    Config-SaveStepId $ext.StepId
}

function Config-ResetLastBootTimeIfDifferentToCurrent
{
    $config = Config-Get
    if([string]::IsNullOrEmpty($config.RestartRequiredIfEqualsTimeOrNull))
    {
        return
    }
    
    $lastBootTime = Get-LastBootTime
    if($lastBootTime -eq $config.RestartRequiredIfEqualsTimeOrNull)
    {
        # Are same, probably just run and not rebooted, leave as is so will offer to reboot.
    } else 
    {
        # Are different, probably was run a while ago and not rebooted by script
        $config.RestartRequiredIfEqualsTimeOrNull = $null
        Config-WriteOutConfig $config
    }
}

function Config-NeedsToReboot
{
    $config = Config-Get
    $isNOE = [string]::IsNullOrEmpty($config.RestartRequiredIfEqualsTimeOrNull)
    return (-not $isNOE)
}