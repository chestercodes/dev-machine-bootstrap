$chocoExe = "C:\ProgramData\chocolatey\bin\choco.exe"
$codeExe = "C:\Program Files\Microsoft VS Code\bin\code.cmd"

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

function StartProcess
{
    param ($exePath, $callArgs, $runInTestMode = $false)
    
    if((-not $runInTestMode) -and ($env:DEV_MACHINE_BOOTSTRAP_TEST_MODE -ne $null))
    {
        write-host "$exePath $callArgs"
        return
    }

    write-verbose "Calling $exePath with $callArgs"
    Start-Process -NoNewWindow -Wait -FilePath $exePath -ArgumentList $callArgs
}

function StartProcessAndCaptureOutput
{
    param ($exePath, $callArgs, $runInTestMode = $false)
    
    if((-not $runInTestMode) -and ($env:DEV_MACHINE_BOOTSTRAP_TEST_MODE -ne $null))
    {
        write-host "$exePath $callArgs"
        return
    }

    write-verbose "Calling $exePath with $callArgs"
    
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $exePath
    #$pinfo.RedirectStandardError = $true
    $pinfo.RedirectStandardOutput = $true
    $pinfo.UseShellExecute = $false
    $pinfo.Arguments = $callArgs
    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $pinfo
    $p.Start() | Out-Null
    $p.WaitForExit()
    $stdout = $p.StandardOutput.ReadToEnd()
    #$stderr = $p.StandardError.ReadToEnd()
    return $stdout
}

function Get-LastBootTime
{
    $lastBootTime = (Get-WmiObject win32_operatingsystem | select @{LABEL='LastBootUpTime';EXPRESSION={$_.ConverttoDateTime($_.lastbootuptime)}}).LastBootUpTime.ToString("o")
    return $lastBootTime
}

function Choco-ProgramIsInstalled
{
    param($chocoId)
    write-verbose "Checking for $chocoId"
    $i = (StartProcessAndCaptureOutput $chocoExe @("list","--local-only","$chocoId") $true)
    write-verbose "$i"
    if($i -match "0 packages")
    {
        return $false
    }
    if($i -match "[^\w]$chocoId [0-9]+")
    {
        write-verbose "Found $chocoId"
        return $true
    }
    return $false
}

function Choco-InstallProgram
{
    param($choco)
    
    if($choco.ChocoSource -ne $null)
    {
        $callArgs = @("install", "-y", $choco.ChocoId, "--source", $choco.ChocoSource)
    } else {
        $callArgs = @("install", "-y", $choco.ChocoId)
    }
    StartProcess $chocoExe $callArgs
}

function Code-GetInstalledExtensions
{
    $results = StartProcessAndCaptureOutput $codeExe @("--list-extensions") $true
    
    return ($results.Split())
}

function Code-InstallExtension
{
    param($ext)
    StartProcess $codeExe @("--install-extension", $ext.ExtId)
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
        RestartRequiredIfEqualsTimeOrNull = ""
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
    Config-WriteOutConfig $config $filePath
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
    write-verbose ("Choco program {0}" -f $choco.ChocoId)

    $config = Config-Get

    $install = $config.ChocoProgramsToInstall -contains $choco.ChocoId
    if($choco.Required -or $install)
    {
        $isAlreadyInstalled = Choco-ProgramIsInstalled $choco.ChocoId
        if(-not $isAlreadyInstalled)
        {
            Choco-InstallProgram $choco
        
            if($choco.RestartRequired)
            {
                write-verbose "Restart required..."
                $lastBootTime = Get-LastBootTime
                $config.RestartRequiredIfEqualsTimeOrNull = $lastBootTime
                Config-WriteOutConfig $config
            }
        }
    }

    Config-SaveStepId $choco.StepId
}

function Code-InstallExtIfInConfig
{
    param ($ext)
    
    if(Config-HasRunStep $ext.StepId) { return }
    write-verbose ("VSCode ext {0}" -f $ext.ExtId)

    $config = Config-Get

    $install = $config.VSCodeExtsToInstall -contains $ext.ExtId
    if($install)
    {
        $installedExts = Code-GetInstalledExtensions
        $isAlreadyInstalled = $installedExts -contains $ext.ExtId
        if($isAlreadyInstalled)
        {
            write-verbose ("{0} is already installed" -f $ext.ExtId)
        } else
        {
            write-verbose ("{0} is not installed" -f $ext.ExtId)
            Code-InstallExtension $ext
        }
    }

    Config-SaveStepId $ext.StepId
}

function Config-ResetLastBootTimeIfDifferentToCurrent
{
    $config = Config-Get
    if([string]::IsNullOrEmpty($config.RestartRequiredIfEqualsTimeOrNull))
    {
        write-verbose "Restart required is null."
        return
    }
    
    $lastBootTime = Get-LastBootTime
    if($lastBootTime -eq $config.RestartRequiredIfEqualsTimeOrNull)
    {
        write-verbose "Probably just run and not rebooted, leave as is so will offer to reboot."
    } else 
    {
        write-verbose "Are different, probably was run a while ago and not rebooted by script"
        $config.RestartRequiredIfEqualsTimeOrNull = ""
        Config-WriteOutConfig $config
    }
}

function Config-NeedsToReboot
{
    $config = Config-Get
    $isNOE = [string]::IsNullOrEmpty($config.RestartRequiredIfEqualsTimeOrNull)
    return (-not $isNOE)
}