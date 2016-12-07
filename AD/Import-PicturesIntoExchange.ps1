<#
	.SYNOPSIS
		Imports user pictures into Exchange by leveraging the badge system database while filtering the accounts to be modified.

	.DESCRIPTION
		Use the script with the filtering parameters to greatly diminish the amount of accounts that will be affected by the change.  It will get the binary
		data from the badge system database and import it directly. Resizing will be done by exchange on the fly.
	
	.PARAMETER TargetDomain
		Targeted domain for importing the pictures.
	
	.PARAMETER Filter
		Filter to be used on the Target Domain. e.g.: Account doesnt have a pic, has employeeId, has HomeDB (Mailbox), etc.
		
	.PARAMETER ExchangeServer
		Use to specify the server to import the exchange commandlets.  If none is specified, it will use COMPUTERNAME.

	.PARAMETER LenelDB
		Connection details for the badge database that contains the pictures use: Server(USE FQDN)\Instance(optional if using default)\DatabaseName
		
	.PARAMETER NumberOfUsers
		Number of users to affect with this change at a time.  Default is 100 but can be anywhere from 1-50K users.

	.PARAMETER LogFile
		Path to the logfile you want to receive all output.

	.EXAMPLE
		Import-PicturesIntoExchange.ps1 -TargetDomain mydomainlab.org -LenelDB LABSQL001.mydomain.lab\AccessControl -NumberOfUsers 200 -Verbose -force

		This will search for users matching the Filter paramater in the mydomainlab.org domain and connecting to the LABSQL001 database server and the 
		AccessControl DB. It will only perform the picture import on a maximum of 200 users.

	.NOTES
		AUTHOR: Marlon.Rodriguez
		VERSION: 1.0
		LASTEDIT: 12/06/2016 11:37:26

	.LINK
		http://stash001.mydomain.com:8990/projects/GIA/repos/powershell/browse/AD

#>
[CmdletBinding(
	SupportsShouldProcess=$True,
	ConfirmImpact="High"
)]
PARAM(
	[Parameter( Mandatory = $True,
				Position = 0,
				ValueFromPipeline = $False,
				HelpMessage = "Domain where the pictures will be imported")]
	[Alias("Target","D","Domain","TD")]
	[ValidateNotNullOrEmpty()] 
	[ValidatePattern("(\w+\.){1,3}\w+")]
	[String]
	$TargetDomain,
	
	[Parameter( Mandatory = $False,
				Position = 1,
				ValueFromPipeline = $False,
				HelpMessage = "Filter to be used for the target domain.")]
	[Alias("ADFilter","F")]
	[ValidateNotNullOrEmpty()]
	[String]
	$Filter = {employeeID -like "*" -and homeMDB -like "*" -and thumbnailPhoto -notlike "*"}, #Users with mailbox, employeeID, and not already have a picture loaded
	
	[Parameter( Mandatory = $False,
				Position = 2,
				ValueFromPipeline = $False,
				HelpMessage = "Exchange server to import the commandlets in FQDN.  Using local computername + userdomain otherwise.")]
	[Alias("Exchange","Server")]
	[ValidateNotNullOrEmpty()]
	[ValidatePattern("(\w+\.){1,3}\w+")]
	[String]
	$ExchangeServer = $env:COMPUTERNAME + "." + $env:USERDNSDOMAIN,
		
	[Parameter( Mandatory = $True,
				Position = 3, 
				ValueFromPipeline = $False,
				HelpMessage="Enter the database connection details in the form: ServerFQDN\Instance\DatabaseName.  Instance can be skipped if using default."
	)]
	[Alias("LenelDatabase","Lenel","BadgeDB")]
	[ValidateNotNullOrEmpty()]
	[ValidatePattern("(\w+\.){1,3}\w+\\(\w+\\)?\w+")] #Enter Server-FQDN\Instance\DBName where the Instance name could be ommited if using the default
	[String]
	$LenelDB,
	
	[Parameter( Mandatory = $False,
				Position = 4, 
				ValueFromPipeline = $False,
				HelpMessage="Number of users to process at this time.  Default: 100"
	)]
	[Alias("Users","UserCount","U","NumberOfUsersToModify")]
	[ValidateRange(1,50000)]
	[int]
	$NumberOfUsers = 100,

	[Parameter( Mandatory = $False,
				Position = 5,
				ValueFromPipeline = $False,
				HelpMessage="Force changes without prompting."
	)]
	[Switch]
	$Force = $False,
	
	[Parameter( Mandatory = $False,
				Position = 6,
				ValueFromPipeline = $False,
				HelpMessage="Logs output to the specified file."
	)]
	[Alias("Log","OutputFile")]
	[ValidateNotNullOrEmpty()]
	[String]
	$LogFile
		
)
Begin {
	If ($LogFile){
		Start-Transcript -Path $LogFile -Force -Append
	}
    function Get-DatabaseData 
    {
	    <#
		    .SYNOPSIS
			    Returns data from a database.
		    .DESCRIPTION
			    This function makes a native SQL client call to a database source.
		    .PARAMETER connectionString
			    This parameter is a standard datasource connection string.
		    .PARAMETER query
			    This parameter is the query that will be executed againt the datasource.
	    #>
	    [CmdletBinding()]
	    param (
		    [string]$connectionString,
		    [string]$query
	    )
	
	    $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection
	    $connection.ConnectionString = $connectionString
	
	    $command = $connection.CreateCommand()
	    $command.CommandText = $query
	
	    $adapter = New-Object -TypeName System.Data.SqlClient.SqlDataAdapter $command
	    $dataset = New-Object -TypeName System.Data.DataSet
	    $adapter.Fill($dataset) | Out-Null
	
	    $dataset.Tables[0]
    }

	$StartTime = Get-Date

	$Verbose = If ($PSCmdlet.MyInvocation.BoundParameters["Verbose"]) {$True} else {$False}
	#$Debug = If ($PSCmdlet.MyInvocation.BoundParameters["Debug"]) {$True; $DebugPreference = "Continue"} else {$False}
	#$WhatIf = If ($PSCmdlet.MyInvocation.BoundParameters["WhatIf"]) {$True} else {$False}
	#$Confirm = If ($PSCmdlet.MyInvocation.BoundParameters["Confirm"]) {$True} else {$False}

	#Import commandlets from Exchange server - If -ExchangeServer is not set then the default is current computername.
	if (!(Get-Command *Set-UserPhoto))
	{
		$Session = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri http://$ExchangeServer/PowerShell -Authentication Kerberos
		Import-PSSession $Session
	}
	$Database = $LenelDB | Select-Object -Property @{N="Server";E={$LenelDB.TrimEnd("\" + $LenelDB.Split("\")[-1])}},@{N="DBName";E={$LenelDB.Split("\")[-1]}}
	Write-Verbose $Database
	$TargetUsers = Get-ADUser -Server $TargetDomain -Properties employeeID -Filter $Filter
	Write-Verbose "Processing: $($TargetUsers.Count) users"
	Write-Verbose "Target Domain: $TargetDomain"
	
    $connection = "Data Source=$($Database.Server);Initial Catalog=$($Database.DBName);Integrated Security=True"
    Write-Verbose "SQL Connection: $connection"

    Write-verbose "Max users to Process: $NumberOfUsers and Found: $($TargetUsers.Count) that match the filter."
	Write-Verbose "Using filter: $Filter"

    $LenelUsersQuery = @'
 SELECT t1.SSNO FROM EMP AS t1 INNER JOIN (
		SELECT EMPID 
			FROM MMOBJS NOLOCK
			WHERE (Type = 0)
		) AS t2
	ON t1.ID = t2.EMPID AND LEN(t1.SSNO) > 4
	GROUP BY SSNO HAVING COUNT(SSNO) = 1
	ORDER BY t1.SSNO

'@

    $LenelUsers = (Get-DatabaseData -query $LenelUsersQuery -connectionString $connection).SSNO.Trim()
    
    $TargetUsers = $TargetUsers | Where-Object  {$_.employeeid -in $LenelUsers}
    Write-Verbose "`t$($TargetUsers.Count) have been found in Lenel..."

	$TotalBytes = 0
	$UsersAffected = 0
}

Process
{

	foreach ($item in $TargetUsers[0..$NumberOfUsers]) #only affect as many users as the Max set.
    {
	    If ($Force -or $pscmdlet.ShouldProcess($TargetDomain,"Import user pictures into $TargetDomain for: $($item.Name)"))
	    {
		    [Byte[]] $UserPic=$null
		    Write-Verbose "`tUser being processed: $($item.Name)..."
		    $query = @'
SELECT t1.LNL_BLOB
FROM MMOBJS AS t1
RIGHT OUTER JOIN (
    SELECT ID 
	FROM EMP
	WHERE LTRIM(RTRIM(SSNO)) = 'EMPLOYEEID'
	GROUP BY ID HAVING COUNT(ID) = 1) AS t2
	ON t1.EMPID = t2.ID
	WHERE (t1.Type = 0)
'@

			    $query = $query.Replace("EMPLOYEEID",$item.employeeID)
                Write-Verbose $query
			    Try
				{
				    $UserPic = (Get-DatabaseData -query $query -connectionString $connection).LNL_BLOB
				    if ($UserPic -ne $null)
				    {
					    Set-UserPhoto -Identity $item.Name -PictureData $UserPic -Confirm:$False
					    Write-Verbose "`t`tUser with empID: $($item.employeeID) should now have a pic of $($UserPic.Length) bytes in size."
					    $TotalBytes += $UserPic.Length
					    $UsersAffected += 1
				    } else {
					    Write-Warning "`t`tNo photo found for user: $($item.Name + " with empID: " + $item.employeeID). Either the empID didnt match or more than one record was returned."
				    }
			    } Catch {
				    $ErrorMessage = $_.Exception.Message
				    $FailedItem = $_.Exception.ItemName
				    Write-Error "`t`tFailed to update user with empID: $($item.employeeID)"
				    Write-Error $FailedItem
				    Write-Error $ErrorMessage
				    break
			    } Finally {}
		    }
	}
	Write-Verbose "Processed $UsersAffected users totaling $("{0:N2}" -f ($TotalBytes / 1MB)) MB."
	if (!($Verbose)){ Write-Output "Processed $UsersAffected users totaling $("{0:N2}" -f ($TotalBytes / 1MB)) MB."}
}

End
{	
    Write-Output "`r`n`r`n****** Script Duration: $(New-TimeSpan ($StartTime) (Get-Date)) ******"
	if ($LogFile){
		Stop-Transcript
	}
}
