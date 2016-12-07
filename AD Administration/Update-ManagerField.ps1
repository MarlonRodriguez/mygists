# -----------------------------------------------------------------------------
#    Script: Update-ManagerField.ps1
#    Author: Marlon Rodriguez
#    Date: 02/26/2014 13:19:42
#    Keywords:
#    Comments:
#
# -----------------------------------------------------------------------------
Param(
    [string] $skippedAccLog = "skippedAccounts.log",
    [string] $skippedMgrLog = "skippedManagers.log"
)

# Peoplesoft etl file updates extensionattribute15 with the manager empid so we use that to
# find the correct one and modify it in AD.

function Get-AllUsers(){
	$strFilter = "(&(objectClass=User)(objectCategory=Person)(!extensionattribute15=\ ))"
	$objDomain = New-Object System.DirectoryServices.DirectoryEntry
	$objSearcher = New-Object System.DirectoryServices.DirectorySearcher

	$objSearcher.SearchRoot = $objDomain
	$objSearcher.PageSize = 250
	$objSearcher.Filter = $strFilter

	$objSearcher.PropertiesToLoad.AddRange(("employeeID","extensionAttribute15"))
	$objSearcher.FindAll() | %{
        if ($_.Properties.extensionattribute15 -match '\d+'){
		     $SCRIPT:Users.Add("$($_.Path)", "$($_.Properties.extensionattribute15)")
        } else {
			$SCRIPT:SkippedAccounts += $_.Path
		}
		if ($_.Properties.employeeid -match '\d+'){
			$SCRIPT:Managers.Add("$($_.Properties.employeeid)","$($_.Path.Substring(7))")
		}
	}
}

function Modify-User([string] $UserID, [string] $ManagerID){
	if ($SCRIPT:Managers.ContainsKey("$ManagerID")){
		$user = [ADSI]"$UserID"
		$user.put("manager", $SCRIPT:Managers["$ManagerID"])
		$user.setInfo()
	} else {
		$SCRIPT:SkippedMgrs+=$ManagerID
	}
}

# ------------- Main ------------------
$SCRIPT:SkippedAccounts = @()
$SCRIPT:SkippedMgrs = @()
$SCRIPT:Users=@{}
$SCRIPT:Managers=@{}
$start_time = Get-Date

Get-AllUsers | Out-Null
Write-Host Found $SCRIPT:Users.Count Users...
#$SCRIPT:Users.Values | Sort-Object -unique | %{ Get-Managers -ManagerID $_ }
Write-Host Found $SCRIPT:Managers.Count managers...
Write-Host Modifying users...
$SCRIPT:Users.getEnumerator() | %{ Modify-User -UserID $_.Key -ManagerID $_.Value }

Write-Host Script done in: (New-TimeSpan (Get-Date) ($start_time))
$SCRIPT:SkippedAccounts > $skippedAccLog
$SCRIPT:SkippedMgrs > $skippedMgrLog
