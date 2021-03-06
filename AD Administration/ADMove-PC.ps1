# -----------------------------------------------------------------------------
#    Script: ADMove-PC.ps1
#    Author: Marlon Rodriguez
#    Date: 02/26/2014 13:36:21
#    Keywords:
#    Comments:
#
# -----------------------------------------------------------------------------
PARAM(
	[string] $PCNames = "PowershellPCs.txt", #Path to list of PCs to execute command on.  Full Path is better.
	[string] $SuccessFile = "PCList.txt", #Path to list of PCs to execute command on.  Full Path is better.
	[string] $LOGFILE = "FailedPCs.log", #Log file for a list of failed PCs.  Full Path is better.
	[string] $LDAP_FILTER = "(&(objectClass=Computer)(operatingSystem=Windows*)(!operatingSystem=Windows*Server*)(!userAccountControl:1.2.840.113556.1.4.803:=2))", #Only get enabled Windows workstations.
	[string] $NewOU = "LDAP://OU=Workstations,DC=my,DC=domain,DC=com",
	[string] $ADSearchRoot = "LDAP://DC=my,DC=domain,DC=com",
	[switch] $ROLLBACK = $false
)
[Environment]::CurrentDirectory= $(Get-ChildItem $LOGFILE).DirectoryName

Function Get-ADComputers{
PARAM(
[string] $ldap_path, 
[string] $ldap_filter
)

	try {
		$objDomain = [System.DirectoryServices.DirectoryEntry]($ldap_path)
		 
		$objSearcher = [System.DirectoryServices.DirectorySearcher]($objDomain)
		$objSearcher.Filter = $ldap_filter
		$objSearcher.PageSize = 500
		$objSearcher.PropertiesToLoad.Clear()
		$objSearcher.PropertiesToLoad.AddRange(@("name","operatingSystem","distinguishedName","pwdLastSet"))

		$objSearcher.FindAll()
	} catch {
		Write-Host "Failed to gather computers: " $Error[0]
		break
	}
}

Function Move-ADObject{
PARAM(
	$PCObject,
	$Success_File,
	$Failure_List,
	$Counter,
	[string] $LDAP_NewPath
)

	$xml = @()
	If (Test-Path $Success_File){
		$xml += Import-Clixml $Success_File
	}
	try {
		$xml += $PCObject
		$([ADSI]"$($PCObject.Properties["adspath"])").MoveTo([ADSI]$LDAP_NewPath)
		$xml | Export-Clixml $Success_File
		$Counter++
	} catch [System.Management.Automation.MethodInvocationException] {
		$Failure_List += $tmpObj.Properties["name"]
	}
}

Function Rollback {
PARAM(
	$ADList,
	$PCs_RollingBack,
	$Counter
)
	$PCs_RollingBack | %{
		$OldObj = $_
		$ADList | %{
			If ([string]::Compare($_.Properties["name"], $OldObj.Properties["name"], $True) -eq 0){
				$NewObj = $_
				Move-ADObject -PCObject $NewObj -Success_File $SuccessFile -Failure_List [REF]$SCRIPT:FailedPCs -Counter [REF]$Counter -LDAP_NewPath $OldObj.Properties["adspath"]
			}
		}
	}
}

#******** Start script execution here ***********
$start_time = Get-Date
$SCRIPT:FailedPCs = @()

#************ Main Loop *****************
[io.file]::Delete($LOGFILE)
$ADObjectsList = $null
$PCs_from_XML = $null
$PCList = Get-Content $PCNames
$SuccessCount = 0
$ADObjectsList = Get-ADComputers -ldap_path $ADSearchRoot -ldap_filter $LDAP_FILTER
$NewObj = $null

if ( $ROLLBACK -eq $true ){
	$PCs_from_XML = Import-Clixml $SuccessFile
	$SuccessCount = Rollback -ADList $ADObjectsList -PCs_RollingBack $PCs_from_XML -Counter [REF]$SuccessCount
} else {
	[io.file]::Delete($SuccessFile)
	$PCList | %{
		$PCName = $_
		$ADObjectsList | %{
			If ([string]::Compare($_.Properties["name"], $PCName, $True) -eq 0){
				$NewObj = $_
				Move-ADObject -PCObject $NewObj -Success_File $SuccessFile -Failure_List [REF]$SCRIPT:FailedPCs -Counter [REF]$SuccessCount -LDAP_NewPath $NewOU
			}
		}
	}
}

Write-Host Script done in: (New-TimeSpan ($start_time) (Get-Date))

if ($SCRIPT:FailedPCs -ne $null){
	"Failed to move: " + $SCRIPT:FailedPCs.Count + " computers."
	"Check logfile at: " + $LOGFILE
	"Failed to update: `r`n" + $SCRIPT:FailedPCs >> $LOGFILE
}
Write-Host "Moved: " $SuccessCount " computers."
"Moved: " + $SuccessCount + " computers." >> $LOGFILE
