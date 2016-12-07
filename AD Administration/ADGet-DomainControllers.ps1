# -----------------------------------------------------------------------------
#    Script: ADGet-DomainControllers.ps1
#    Author: Marlon Rodriguez
#    Date: 02/26/2014 13:44:31
#    Keywords:
#    Comments:
#
# -----------------------------------------------------------------------------
$start_time = Get-Date

#First way
$dom = [System.DirectoryServices.ActiveDirectory.Domain]::getcurrentdomain()
#Get the DC's for the domain
$dom.DomainControllers | select Name
Write-Host $dom.DomainControllers.Count
##Find one DC
#$dom.FindDomainController()
#DC's for all the domains in the forest
$dom.Forest.Domains

Write-Host (New-TimeSpan (Get-Date) ($start_time))

#******* Active Directory domain connection information from hardcoded domain name and Quest ADTools
$adDomain = 'FQDN for the domain here'

#Connect to Active Directory and return information
Write-Host "Starting hardcoded domain name script"
$adConn = connect-QADService -service $adDomain #-credential $adCred
Write-Host "Continue..."
$serverList = get-QADComputer -IncludedProperties "Name,dNSHostName,DN" -SizeLimit 0 -PageSize 250 -ComputerRole 'DomainController'

#Close connection to Active Directory
disconnect-QADService -connection $adConn

Format-Table -InputObject $serverList Name,dNSHostName,DN
Write-Host $serverList.Count
Write-Host (New-TimeSpan (Get-Date) ($start_time))

#********* another using hardcoded values...
Write-Host "and another..."

$dcObj = [adsi]"LDAP://OU=domain controllers,dc=internal,dc=domain,dc=com"
$dcs = $dcObj.PSBase.Children | %{ $_.name }
$dcs
Write-Host "Total:" $dcs.Count
Write-Host (New-TimeSpan (Get-Date) ($start_time))

#********* Another way
Write-Host "Last...I promise..."
$forestname = "forest name" #"domain.com"
$fcontext = new-object System.DirectoryServices.ActiveDirectory.DirectoryContext("Forest",$forestname)
$dlist = [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($fcontext).Domains
$dlist | %{
	$dcontext = new-object System.DirectoryServices.ActiveDirectory.DirectoryContext("Domain",$_)
	$dclist = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($dcontext).FindAllDiscoverableDomainControllers()
	$dclist | %{$_.name}
	Write-Host "Total:" $dclist.Count
}

Write-Host (New-TimeSpan (Get-Date) ($start_time))

