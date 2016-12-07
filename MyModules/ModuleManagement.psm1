# -----------------------------------------------------------------------------
#    Script: ModuleManagement.psm1
#    Author: Marlon Rodriguez
#    Date: 02/26/2014 09:36:37
#    Keywords:
#    Comments:
#
# -----------------------------------------------------------------------------
Set-StrictMode -Version Latest

Function Load-ISEPackV2
{
<#
   .Synopsis
    Loads the ISEPack v2 modules for the ISE editor.

   .PARAMETER Remove
    Optional switch to unload the modules.

   .DESCRIPTION
    Simply loads/unloads all the modules in the pack.

   .Notes
    AUTHOR: Marlon.Rodriguez
    LASTEDIT: 02/18/2014 14:19:48

#>
[CmdletBinding()]
PARAM(
    [Parameter( Mandatory = $False, Position = 0, ValueFromPipeline = $False)]
    [switch] $Remove
)
    BEGIN {
        $Verbose = If ($PSCmdlet.MyInvocation.BoundParameters["Verbose"]) {$True} else {$False}
        $Debug = If ($PSCmdlet.MyInvocation.BoundParameters["Debug"]) {$True; $DebugPreference = "Continue"} else {$False}
    }
    PROCESS {
        If ($remove){
            Check-ModuleLoaded ISELoadModules,ISECreamBasic,ISEPackV2,ScriptCop,EZOut,Pipeworks,RoughDraft,ShowUI -Remove:$Remove -Force -Debug:$Debug -Verbose:$Verbose
        } Else {
            Check-ModuleLoaded ShowUI,RoughDraft,Pipeworks,EZOut,ScriptCop,ISEPackV2,ISECreamBasic,ISELoadModules -Debug:$Debug -Verbose:$Verbose
        }
    }
}

Function Check-ModuleLoaded
{
<#
    .SYNOPSIS
    Checks if a module is loaded and imports or removes it.

    .DESCRIPTION
    This function checks for a module by using the get-module cmdlet and if nothing comes back it calls the import-module cmdlet to load it.  If the -Remove switch was used then it removes the modules.

    .PARAMETER ModuleName
    Requiered module name used to check and load the module.

    .PARAMETER Remove
    Optional switch Remove to unload the module if present.  If the switch is not specified it will load/import instead.

    .PARAMETER Force
    Optional Force switch to force loading/unloading the module.

    .Example

    Check-ModuleLoaded ConfigurationManager,ActiveDirectory
    Check/load configuration manager and active directory.  Use it at the beginning of a script that needs cmdlets from that module to make sure it's loaded if it's missing.

    .Example

    Check-ModuleLoaded ActiveDirectory -Remove -Verbose
    Check and load/unload some module while giving verbose output.


    .Notes
    AUTHOR: Marlon.Rodriguez
    LASTEDIT: 02/18/2014 22:48:46

#>
    [CmdletBinding(
        SupportsShouldProcess=$True,
        ConfirmImpact="low"
    )]
    PARAM(
        [Parameter( Mandatory = $True, Position = 0, ValueFromPipeline = $True)]
        [string[]] $ModuleName,
        [Parameter( Mandatory = $False, Position = 1, ValueFromPipeline = $False)]
        [switch] $Remove,
        [Parameter( Mandatory = $False, Position = 2, ValueFromPipeline = $False)]
        [switch] $Force
    
    )
    BEGIN {
        $Verbose = If ($PSCmdlet.MyInvocation.BoundParameters["Verbose"]) {$True} else {$False}
        $Debug = If ($PSCmdlet.MyInvocation.BoundParameters["Debug"]) {$True; $DebugPreference = "Continue"} else {$False}
        $WhatIf = If ($PSCmdlet.MyInvocation.BoundParameters["WhatIf"]) {$True} else {$False}
        $Confirm = If ($PSCmdlet.MyInvocation.BoundParameters["Confirm"]) {$True} else {$False}
    }
    PROCESS {
        $ModuleName | % {
            $mod = $_
            if ($pscmdlet.ShouldProcess($mod)){
                If ($mod -ieq "configurationmanager" ){
                    $mod = (Get-Item -Path $Env:SMS_ADMIN_UI_PATH).Parent.FullName + "\ConfigurationManager.psd1"
                }
                If (-not (Get-Module $mod) -and -not $Remove) {
                    Import-Module $mod -Force:$Force -Verbose:$Verbose -Debug:$Debug
                    If (Get-Module $mod){
                        Write-Output "$mod was loaded..."
                    }
                } elseif ((Get-Module $mod) -and $Remove) {
                    Remove-Module $mod -Force:$Force -Verbose:$Verbose -Debug:$Debug -WhatIf:$WhatIf -Confirm:$Confirm
                    If (-not (Get-Module $mod)){
                        Write-Output "$mod was unloaded..."
                    }
                }
            }
        }
    }
}

