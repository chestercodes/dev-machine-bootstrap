$chocoExe = "C:\ProgramData\chocolatey\bin\choco.exe"
$codeExe = "C:\Program Files\Microsoft VS Code\bin\code.cmd"

# ChocoProgram, VsCodeExt need a StepId property that is unique
function ChocoProgram
{
    param(
        [string]$chocoId,
        [string]$description,
        [string[]]$specificToRoles = @(),
        [bool]$required = $false,
        $chocoSource = $null
    )
    if($chocoSource -eq $null)
    {
        $stepId = "choco-$chocoId"
    } else {
        $stepId = "choco-$chocoSource-$chocoId"
    }
    $p = @{
        StepId = $stepId
        ChocoId = $chocoId
        Description = $description
        SpecificToRoles = $specificToRoles
        Required = $required
        ChocoSource = $chocoSource
    }
    $o = New-Object psobject -Property $p;
    return $o
}

function VsCodeExt
{
    param(
        [string]$extId,
        [string]$description,
        [string[]]$specificToRoles = @()
    )
    $stepId = "vscodeext-$extId"
    $p = @{
        StepId = $stepId
        ExtId = $extId
        Description = $description
        SpecificToRoles = $specificToRoles
    }
    $o = New-Object psobject -Property $p;
    return $o
}

function StartProcess
{
    param ($exePath, $callArgs, $runInTestMode = $false)
    
    if((-not $runInTestMode) -and (IsInTestMode))
    {
        start-sleep -milliseconds 400
        write-host "$testModePrefix $exePath $callArgs"
        return
    }

    write-verbose "Calling $exePath with $callArgs"
    $p = Start-Process -NoNewWindow -PassThru -Wait -FilePath $exePath -ArgumentList $callArgs
    $exitCode = $p.ExitCode

    if($exitCode -ne 0)
    {
        write-host "LASTEXITCODE is not 0. It is $exitCode"
        
        if(IsInSilentMode)
        {
            write-host "Is in silent mode, exiting as can't take user input."
            exit 1
        }
        
        $isChoco = $exePath -eq $chocoExe
        if($isChoco -and ($exitCode -eq 3010))
        {
            # chocolatey has a couple of non-zero exit codes which indicate that the install was successful
            # 3010 means that all is ok, but a restart is needed for the changes to take effect.

            while($true)
            {
                $yn = read-host -prompt "Last exit code was indicates that a restart is needed.`n   Restart machine? (y/n)"
                if($yn -eq "y")
                {
                    write-host "restarting computer"
                    Stop-Transcript
                    restart-computer
                }
                if($yn -eq "n")
                {
                    break
                }
            }
        }

        while($true)
        {
            $yn = read-host -prompt "Last exit code was non-zero. Proceed? (y/n)"
            if($yn -eq "y")
            {
                break
            }
            if($yn -eq "n")
            {
                exit 1
            }
        }
    }
}

function IsInSilentMode
{
    return ($env:DEV_MACHINE_BOOTSTRAP_SILENT_MODE -ne $null)
}

$testModePrefix = "TESTMODE:"

function IsInTestMode
{
    return ($env:DEV_MACHINE_BOOTSTRAP_TEST_MODE -ne $null)
}

function StartProcessAndCaptureOutput
{
    param ($exePath, $callArgs, $runInTestMode = $false)
    
    if((-not $runInTestMode) -and (IsInTestMode))
    {
        write-host "$testModePrefix $exePath $callArgs"
        return
    }

    if(IsInTestMode)
    {
        # This is hit for calls like code --list-extensions 
        # calls that needs some return value to decide where to go next
        return ""
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

function IsRunningInContainer
{
    [string]$userName = $env:USERNAME
    return $userName.StartsWith("Container")
}

function Get-UsernameFromEnv
{
    [string]$userName = $env:USERNAME
    if([string]::IsNullOrEmpty($userName))
    {
        # this really shouldn't happen, windows should always 
        # have something as the USERNAME
        return "josephine.bloggs"
    }
    
    if(IsRunningInContainer)
    {
        return "chester.burbidge"
    }

    return $userName
}

function CapitaliseWord
{
    param ([string]$word)
    $firstLetter = $word.Substring(0,1).ToUpper()
    $rest = $word.Substring(1).ToLower()
    return "$firstLetter$rest"
}

function Name-GuessFromEnv
{
    $userName = Get-UsernameFromEnv
    $name = ($userName.Split('.') | % { CapitaliseWord $_ }) -join " "
    write-verbose "Name guessed to be $name"
    return $name
}

function Email-GuessFromEnv
{
    $userName = Get-UsernameFromEnv
    $email = "$username@your-company.com"
    write-verbose "Email guessed to be $email"
    return $email
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
    
    # this is a bit extra, basically want the regex to match
    # the package name and then a number, but don't want there to 
    # be a word char before the name. so want 'git' to not match poshgit 1.2.3
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
        write-verbose "Config file doesn't exist at $configPath"
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
    param($msg, $guessValue = $null, $guessMsg = $null)
    
    while($true)
    {
        if($guessValue -eq $null)
        {
            $theValue = read-host -prompt $msg
            $yn = read-host -prompt "I heard '$theValue' is this ok? (y/n)"
        } else {
            $theValue = $guessValue
            $yn = read-host -prompt $guessMsg
        }
        
        if($yn -eq "y")
        {
            return $theValue
        }
        $guessValue = $null
    }
}

function Config-EnsureNameExists
{
    param($filePath=$null)
    $config = Config-Get $filePath
    if([string]::IsNullOrEmpty($config.Name))
    {
        write-verbose "Name doesn't exist"
        $nameFromEnv = Name-GuessFromEnv
        $name = Get-Input "Please enter name" $nameFromEnv ("I've guessed your name to be '$nameFromEnv'. Is this ok? (y/n)")
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
        $emailFromEnv = Email-GuessFromEnv
        $email = Get-Input "Please enter email" $emailFromEnv ("I've guessed your email to be '$emailFromEnv'. Is this ok? (y/n)")
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
    
    if(Config-HasRunStep $choco.StepId)
    {
        write-verbose ("Has already run step {0}" -f $choco.StepId)
        return
    }
    write-verbose ("Choco program {0}" -f $choco.ChocoId)

    $config = Config-Get

    $install = $config.ChocoProgramsToInstall -contains $choco.ChocoId
    if($choco.Required -or $install)
    {
        $isAlreadyInstalled = Choco-ProgramIsInstalled $choco.ChocoId
        if(-not $isAlreadyInstalled)
        {
            Choco-InstallProgram $choco
        }
    }

    Config-SaveStepId $choco.StepId
}

function Code-InstallExtIfInConfig
{
    param ($ext)
    
    if(Config-HasRunStep $ext.StepId) 
    {
        write-verbose ("Has already run step {0}" -f $ext.StepId)
        return
    }
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

function RunStep
{
    param ($stepId, $action)
    
    if(Config-HasRunStep $stepId)
    {
        write-verbose ("Has already run step {0}" -f $stepId)
        return
    }

    write-verbose "Running '$stepId'"
    $action.Invoke()

    Config-SaveStepId $stepId
}

function TellUserAboutStep
{
    param($msg)
    $bar = "===================================================================="
    write-host "`n$bar`n$msg`n$bar`n"
    if(IsInSilentMode){ return }
    Read-Host -prompt "Hit enter to proceed"
}

function WindowsFeature-InstallOrEnable
{
    param ($feature)
    Write-Host "Installing/Enabling $feature"
    $callArgs = @("install", "-y", $feature, "--source", "windowsfeatures")
    StartProcess $chocoExe $callArgs
}

function Set-FolderPermissions
{
    param ($folderPath, $permUser, $requiredPermissions)
    $Acl = Get-Acl $folderPath
    $Ar = New-Object System.Security.AccessControl.FileSystemAccessRule($permUser, $requiredPermissions, "ContainerInherit,ObjectInherit", "None", "Allow")
    if(-not(IsInTestMode))
    {
        $Acl.SetAccessRule($Ar)
        Set-Acl $folderPath $Acl
    }
}

function Run
{
    param ($cmd)
    if(IsInTestMode){
        write-host "$testModePrefix $cmd"
    } else {
        Invoke-expression -command $cmd
    }
}

#####################################################
#
#   Everything below this assumes that
#   the following variables exist:
#    - $chocoPrograms
#    - $vsCodeExtensions
#
#####################################################

$allRole = "all"

function GetUniqueRoles
{
    $roles = @($allRole)
    
    foreach ($p in $chocoPrograms)
    {
        foreach ($r in $p.SpecificToRoles)
        {
            if(-not($roles -contains $r))
            {
                $roles += $r
            }
        }
    }
    foreach ($e in $vsCodeExtensions)
    {
        foreach ($r in $e.SpecificToRoles)
        {
            if(-not($roles -contains $r))
            {
                $roles += $r
            }
        }
    }
    return $roles
}

function ShowProgramForRole
{
    param ($software, $role)
    $roleIsAll = $role -eq $allRole
    $isEmpty = $software.SpecificToRoles.Length -eq 0
    $isSpecificToRole = $software.SpecificToRoles -contains $role
    return ($roleIsAll -or $isEmpty -or $isSpecificToRole)
}

function FormatSpecificToRoles {
    param ($specificToRoles)
    if($specificToRoles.Length -eq 0)
    {
        return ""
    }
    $specificToRoles = $specificToRoles -join "|"
    return "<$specificToRoles>"
}

function List-ScriptInfo
{
    write-host "`nPrograms that can be installed:`n"
    foreach ($p in $chocoPrograms)
    {
        $description = "{0} {1}" -f $p.Description, (FormatSpecificToRoles $p.SpecificToRoles)
        write-host ("- {0}" -f $description)
    }
    
    write-host "`nVSCode extensions that can be installed:`n"

    $orderedByDesc = $vsCodeExtensions | Sort-object -property Description
    foreach ($ext in $orderedByDesc)
    {
        $description = "{0} {1}" -f $ext.Description, (FormatSpecificToRoles $ext.SpecificToRoles)
        write-host ("- {0}" -f $description)
    }   
}

function Generate-Config
{
    Config-EnsureNameExists
    Config-EnsureEmailExists

    $uniqueRoles = GetUniqueRoles

    while ($true)
    {
        $resp = read-host -prompt "What software are you interested in? ($uniqueRoles)"
        if($uniqueRoles -contains $resp)
        {
            $role = $resp
            break
        }    
    }

    write-host "Showing $role software"

    write-host "`nPrograms that can be installed:`n"
    foreach ($p in $chocoPrograms)
    {
        if(ShowProgramForRole $p $role)
        {
            Config-AskInstallChocoProgram $p
        }
    }

    write-host "`nVS Code extensions that can be installed:`n"
    $orderedByDesc = $vsCodeExtensions | Sort-object -property Description
    foreach ($ext in $orderedByDesc)
    {
        if(ShowProgramForRole $ext $role)
        {
            Config-AskInstallVSCodeExt $ext
        }
    }
}

function Install-ProgramsFromConfig
{
    Write-Host "Install programs from config"
    foreach ($p in $chocoPrograms)
    {
        Choco-InstallProgramIfInConfig $p
    }
}

function Install-VSCodeExtensionsFromConfig
{
    Write-Host "Install code extensions from config"
    
    foreach ($ext in $vsCodeExtensions)
    {
        Code-InstallExtIfInConfig $ext
    }    
}