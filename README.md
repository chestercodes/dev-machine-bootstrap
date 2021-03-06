# dev-machine-bootstrap

Powershell script for teams to setup dev machines. 

It aims to be:

- easy to use, clone the repo and run Install.ps1 in admin mode.
- idempotent, so that it an be run multiple times if the script steps evolve over time.
- a heavy user of chocolatey to Install programs and windows features
- customisable to a teams requirements, with required programs to install and ask user whether they want to install others.
- runnable in both an interactive and silent mode, where the programs to install are configured by a json file.
- debuggable, write out the session to log files on each invocation


## Switches

The script is most likely to be used without any switches. But it has a few other tricks up it's sleeve.

- `-List` - List the programs that the script knows how to install
- `-Silent` - Run the script in silent mode. Needs a pre-generated config file to be used properly
- `-GenerateConfig` - Generate a config file to be used with the script. 

## To customise for a team/company

Each team/company will want to customise the script for their own personal developer experience.

This can be done by changing the `$chocoPrograms` and `$vsCodeExtensions` variables to include the appropriate choco packages and code extensions.

Then adding "steps" in the form of powershell code blocks which are run with the `RunStep` function. 

``` powershell
# custom code saved as a script block as a powershell variable
$customStepOne = {
    Write-host "This is a custom step to be run.
    This could setup the machine to any internal systems or other configuration"
}

# invocation of custom step with step Id of "step-custom-one"
RunStep "step-custom-one" $customStepOne
```

Examples of this are also seen with the `$ensureChocoIsInstalled` and `$configureGit` variables.

## To use

Clone repository, open a powershell shell as an administrator and run:

`./Install.ps1`


## Reason/rational

Installing programs is annoying, anything to automate it is good. As much as having a page in a wiki is better than nothing, it's not much better...

The idea of this being config driven is that it could potentially become part of an onboarding process. The new starter could be given a list of programs (with the `-list` argument) and they could chose the ones that they want. The script could then be used to send them a laptop that is ready to go from the start.