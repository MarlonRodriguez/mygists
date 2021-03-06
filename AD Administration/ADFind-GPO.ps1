PARAM(
[string] $DomainName = "mydomain.com",
[string] $GPOFilter = "IE"
)

$gpm = New-Object -ComObject GPMgmt.GPM
$k = $gpm.GetConstants()
$dom = $gpm.GetDomain($DomainName,"","")

$sc1 = $gpm.CreateSearchCriteria()
$sc1.Add($k.SearchPropertyGPODisplayName, $k.SearchOpContains, "IE")
$gpos = $dom.SearchGPOs( $sc1)

##To back them up
#$gpos | %{
#	$result = $_.Backup("c:\mybackups", "Backup1")
#	$result.result
#}
#
##To restore them
#$bd = $gpm.GetBackupDir( "C:\mybackups")
#$sc1 = $gpm.CreateSearchCriteria()
#$sc1.Add( $k.SearchPropertyGPODisplayName, $k.SearchOpContains, "IE")
#
#$bgpo = $bd.SearchBackups( $sc1)
#
#$bgpo | %{
#	$dom.RestoreGPO( $_, $k.DoNotValidateDC )
#}

##Reporting
#$gpos | %{
#	$result = $_.GenerateReport( $k.ReportHTML)
#	$htmlReport = $result.result
#}