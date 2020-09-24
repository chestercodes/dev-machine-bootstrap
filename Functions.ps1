# ChocoProgram, VsCodeExt all need a StepId property that is unique and immutable
function ChocoProgram
{
    param(
        [string]$stepId,
        [string]$chocoId,
        [string]$description,
        [bool]$required = $false,
        [string]$testCommand = $null
    )
    $p = @{
        StepId = $stepId
        ChocoId = $chocoId
        Description = $description
        Required = $required
        TestCommand = $testCommand
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
        write-error "$p is not on PATH, cannot continue"
        exit 1
    }
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

function Code-GetInstalledExtensions
{
    AbortUnlessVSCodeExists
    return code --list-extensions
}

function Code-InstallExtension
{
    param($ext)
    AbortUnlessVSCodeExists
    return code --list-extensions
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


