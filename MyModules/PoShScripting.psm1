# -----------------------------------------------------------------------------
#    Script: PoShScripting.psm1
#    Author: Marlon Rodriguez
#    Date: 02/26/2014 12:31:08
#    Keywords:
#    Comments:
#
# -----------------------------------------------------------------------------
Set-StrictMode -Version Latest

Function Add-Help
{
<#
    .SYNOPSIS
    Adds the help section to your function or script.

    .DESCRIPTION
    Adds help text to your function or script.  It uses parameters to automatically add the paramaters and examples sections.
    It also adds most of the settings that you can add to your parameter definitions so remember to remove anything not needed.
    
    .PARAMETER Params
    Enter the names of the parameters for your function.
    
    .PARAMETER Examples
    Number of examples you will give.

    .Example

    Add-Help -Params Params,Examples -Examples 2

    This example shows you how to use all of the parameters to create the help for this function.


    .Example

    Add-Help -Params Params,Examples

    Use just the -params swith to only give parameter names without any examples.


    .Notes
    AUTHOR: Marlon Rodriguez
    LASTEDIT: 02/26/2014 09:47:16

    .LINK
    http://wwww.google.com


#>
PARAM(
    [Parameter( Mandatory = $False, Position = 0, ValueFromPipeline = $False)]
    [string[]] $Params,
    [Parameter( Mandatory = $False, Position = 1, ValueFromPipeline = $False)]
    [int32] $Examples = 0
)
    Begin {
        $helpText = @"
<#
    .SYNOPSIS
    This does that

    .DESCRIPTION
    This command does this by doing that, including this other thing.  You can use this and that but whatch out for this other thing.

"@
        $position = 0
        $paramDef = @"


"@
        $ExampleText = @"


"@
    }
    PROCESS {
        foreach ($item in $Params){
            $helpText += @"
    
    .PARAMETER $item
    This parameter expects, needs, required, default value, piped?...

"@
            $paramDef += @"
    #**** Remove the ParamaterSetName if you are not using it or rename it to what you want if you are... http://go.microsoft.com/fwlink/?LinkId=142183
    #Get-Help about_Functions_Advanced_Parameters
    [Parameter( Mandatory = `$True,
                ParameterSetName="p$position",
                Position = $position, 
                ValueFromPipeline = `$True,
                ValueFromPipelineByPropertyName=`$True,
                HelpMessage="Enter something into this parameter to get something."
    )]
    [Alias("Alias1","A","myhugealias")]
    [AllowNull()] OR [ValidateNotNull()] OR [ValidateSet("Low", "Average", "High")] OR [ValidateNotNullOrEmpty()] OR [ValidateScript({$_ -ge (get-date)})] OR [ValidateRange(0,10)] OR [ValidatePattern("[0-9][0-9][0-9][0-9]")] OR [ValidateLength(1,10)] OR [ValidateCount(1,5)] OR [AllowEmptyCollection()] OR [AllowEmptyString()]
    [String[]]
    `$$item

"@
            $position++
        }
        for ($i = 0; $i -lt $Examples; $i++)
        {
            $helpText += @"

    .Example

    <Command Example goes here, remove the greater than and less than symbols.>

    This example accomplishes many things including blah, blah.  It does it by blah, blah. If this doesnt happen then blah, blah...

"@
        }
    }
    END {

        $helpText += @"

    .Notes
    AUTHOR: $env:username
    LASTEDIT: $(Get-Date)

    .LINK
    http://wwww.google.com


#>
[CmdletBinding(
    DefaultParametersetName="p2", #remove if this is not used. http://blogs.msdn.com/b/powershell/archive/2008/12/23/powershell-v2-parametersets.aspx
    SupportsShouldProcess=`$True, #remove if not used.
    ConfirmImpact="low"
)]
PARAM(

"@
        $helpText += $paramDef
        $helpText += @"
)
    BEGIN {
        # This part only runs once if pipeline input is expected.  Not needed if you are not supporting it.
        `$Verbose = If (`$PSCmdlet.MyInvocation.BoundParameters["Verbose"]) {`$True} else {`$False}
        `$Debug = If (`$PSCmdlet.MyInvocation.BoundParameters["Debug"]) {`$True; `$DebugPreference = "Continue"} else {`$False}
        `$WhatIf = If (`$PSCmdlet.MyInvocation.BoundParameters["WhatIf"]) {`$True} else {`$False}
        `$Confirm = If (`$PSCmdlet.MyInvocation.BoundParameters["Confirm"]) {`$True} else {`$False}
    }
    PROCESS {
        # This part could run many times depending on what the pipeline sent to it.  If not supporting pipeline input you dont need it.
        If (`$pscmdlet.ShouldProcess(`$$({If ($Params -is [array]){$Params[0]} else {$Params}}))){
            #If the "-whatif" switch is not passed then do this...
        }
    }
    END {
        #Might not be needed, only runs once at the end.
    }

"@
    $psise.CurrentFile.Editor.InsertText($helpText)
    }
}

Function Add-ScriptHeader
{
<#
    .Synopsis
    This will add a script header to the current document in ISE.
    .SYNTAX
    Add-HeaderToScript

    .DESCRIPTION
    This is a simple command to add the header I want to a script loaded in ISE. The script needs to be saved first so that it can use it's name in the header fields.

   .Notes
    AUTHOR: Marlon.Rodriguez
    LASTEDIT: 02/17/2014 12:26:38

#>
    $header = @"
# -----------------------------------------------------------------------------
#    Script: $(split-path -Path $psISE.CurrentFile.FullPath -Leaf)
#    Author: $env:username
#    Date: $(Get-Date)
#    Keywords:
#    Comments:
#
# -----------------------------------------------------------------------------
"@
    $psise.CurrentFile.Editor.InsertText($header)
}

