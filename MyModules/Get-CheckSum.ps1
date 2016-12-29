Function Get-CheckSum {
<#
    .SYNOPSIS
    Gets the checksum for a set of files or folders.

    .DESCRIPTION
    This will use MS's built in certutil to calculate the hash for a file or set of files\folders.
    
    .PARAMETER File
    Please enter the file or folder name.  You can use a comma separated list of files and folders.
    
    .PARAMETER Hash
    Please name the algoright to use.  Default is MD5.

    .Example

    <Command Example goes here, remove the greater than and less than symbols.>

    This example accomplishes many things including blah, blah.  It does it by blah, blah. If this doesnt happen then blah, blah...

    .Example

    <Command Example goes here, remove the greater than and less than symbols.>

    This example accomplishes many things including blah, blah.  It does it by blah, blah. If this doesnt happen then blah, blah...

    .Notes
    AUTHOR: me14114
    LASTEDIT: 12/29/2016 15:21:07

    .LINK
    http://wwww.google.com


#>
[CmdletBinding(
    DefaultParametersetName="p2", #remove if this is not used. http://blogs.msdn.com/b/powershell/archive/2008/12/23/powershell-v2-parametersets.aspx
    SupportsShouldProcess=$True, #remove if not used.
    ConfirmImpact="low"
)]
PARAM(

    #**** Remove the ParamaterSetName if you are not using it or rename it to what you want if you are... http://go.microsoft.com/fwlink/?LinkId=142183
    #Get-Help about_Functions_Advanced_Parameters
    [Parameter( Mandatory = $True,
                Position = 0, 
                ValueFromPipeline = $True,
                ValueFromPipelineByPropertyName=$False,
                HelpMessage="File(s) or Folder(s) to get the checksum."
    )]
    [Alias("Folder","Item","Files")]
    [ValidateNotNullOrEmpty()]
    [String[]]
    $File,
    [Parameter( Mandatory = $False,
                Position = 1, 
                ValueFromPipeline = $False,
                HelpMessage="Hash algorithm to use, default is MD5."
    )]
    [Alias("Algorithm","CheckSumType", "HashAlgorithm")]
    [ValidateSet("MD2", "MD4", "MD5", "SHA1", "SHA256", "SHA384", "SHA512")]
    [String[]]
    $Hash = "MD5"
)
    BEGIN {
        # This part only runs once if pipeline input is expected.  Not needed if you are not supporting it.
        $Verbose = If ($PSCmdlet.MyInvocation.BoundParameters["Verbose"]) {$True} else {$False}
        $Debug = If ($PSCmdlet.MyInvocation.BoundParameters["Debug"]) {$True; $DebugPreference = "Continue"} else {$False}
        $WhatIf = If ($PSCmdlet.MyInvocation.BoundParameters["WhatIf"]) {$True} else {$False}
        $Confirm = If ($PSCmdlet.MyInvocation.BoundParameters["Confirm"]) {$True} else {$False}
    }
    PROCESS {
        # This part could run many times depending on what the pipeline sent to it.  If not supporting pipeline input you dont need it.
        $File | %{
            If ($pscmdlet.ShouldProcess("Getting hash for: $_")){
                $item = $_
                $itemObject = Get-Item $_ -ErrorAction SilentlyContinue
                if ($itemObject -and $itemObject.Attributes.HasFlag( [System.IO.FileAttributes]::Directory)){
                    $item
                    Get-ChildItem $itemObject | %{ Get-CheckSum "$($item)\$($_.Name)" $Hash}
                } else {
                    Write-Output $("$item`t" + $((CertUtil -hashfile $item $Hash)[1] -replace " ","" ))
                }
            }
        }
    }
    END {
        #Might not be needed, only runs once at the end.
    }

}
