Function Test-Property{
<#
	.SYNOPSIS
	Checks a property exists before trying to get the value.

	.DESCRIPTION
	Use this command to check if an item property exists before doing anything else against it.
	
	.PARAMETER Path
	Path to the item that contains the property.  Required.
	
	.PARAMETER Property
	Name of the property we are checking. Required

	.Example

	Test-Property -Path HKLM:SYSTEM\CurrentControlSet\Services\MountMgr -Name NoAutoMount

	Checks the property "NoAutoMount" to see if it exists before trying to query, modify it, or create it.

	.Notes
	AUTHOR: Marlon.Rodriguez
	LASTEDIT: 08/20/2015 09:10:55


#>
[CmdletBinding(
	ConfirmImpact="low"
)]
PARAM(
	[Parameter( Mandatory = $True,
				Position = 0, 
				HelpMessage="Enter the full path to the parent item of the property."
	)]
	[ValidateNotNullOrEmpty()]
	[String]
	$Path,
	[Parameter( Mandatory = $True,
				Position = 1, 
				HelpMessage="Enter the name of the property we are checking."
	)]
	[Alias("Prop","Name")]
	[ValidateNotNullOrEmpty()]
	[String]
	$Property
)
    if ((Test-Path $Path) -and ((Get-ItemProperty $Path).PSObject.Properties[$Property])){
        Get-ItemProperty $Path -Name $Property
    }
}

