# SearchGPOsForSetting.ps1
#
# Shamelessly stolen from this page (after fixing 1 bug):
# http://blogs.technet.com/b/grouppolicy/archive/2009/04/14/tool-images.aspx
# http://blogs.technet.com/b/grouppolicy/archive/2009/04/17/find-settings-in-every-gpo.aspx
#
# Powershell script that does the following:
# SearchGPOsForSetting.ps1  [–IsComputerConfiguration] <boolean> [-Extension] <string>
# [-Where] </string><string> [-Is] </string><string> [[-Return] </string><string>] [[-DomainName] </string><string>]
# [-Verbose] [-Debug] [-ErrorAction <actionpreference>] [-WarningAction </actionpreference><actionpreference>]
# [-ErrorVariable <string>] [-WarningVariable </string><string>] [-OutVariable </string><string>] [-OutBuffer <int32>]
#
# Example: .\SearchGPOsForSetting.ps1 -IsComputerConfiguration $true -Extension Security -Where Name -Is LockoutDuration -Return SettingNumber
# Example: .\SearchGPOsForSetting.ps1 -IsComputerConfiguration $true -Extension Registry -Where Name -Is ACSettingIndex -Return SettingNumber
param (
[Parameter(Mandatory=$true)]  
[Boolean] $IsComputerConfiguration,
[Parameter(Mandatory=$true)]  
[string] $Extension,  
[Parameter(Mandatory=$true)]  
[string] $Where,
[Parameter(Mandatory=$true)]
[string] $Is,
[Parameter(Mandatory=$false)] 
[string] $Return,
[Parameter(Mandatory=$false)]  
[string] $DomainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
)


function print
{	
	param
	(
		$displayName,
		$value
	)
    
	$host.UI.WriteLine();
    
	$stringToPrint = "The Gpo '" + $displayName + "' has a " + $Extension + " setting where '" + $Where + "' is equal to '" + $Is + "'";
    
	if ($Return -ne $null)
	{
		$stringToPrint += " and the value of its '" + $Return + "' property is: '" + $value + "'";
	}
    
	$host.UI.Write([ConsoleColor]::Magenta, [ConsoleColor]::Black,	$stringToPrint);
	$host.UI.WriteLine();
}

function processNodes
{
	param
    	(
		$nodes,
		$foundWhere
	)
    
	$thePropertyWeWant = $Where;
    
	# If we already found the $Where then we are looking for our $Return value now.
	if ($foundWhere)
	{
		$thePropertyWeWant = $Return;
	}
    		
	foreach($node in $nodes)
	{
		$valueWeFound = $null;
    
		#Here we are checking siblings										
		$lookingFor = Get-Member -InputObject $node -Name $thePropertyWeWant;		        

		if ($lookingFor -ne $null)
		{
			$valueWeFound = $node.($lookingFor.Name);
		}
		else #Here we are checking attributes.
		{
			if ($node.Attributes -ne $null) 
			{                
				$lookingFor = $node.Attributes.GetNamedItem($thePropertyWeWant);

				if( $lookingFor -ne $null)
				{                
					$valueWeFound = $lookingFor;
				}
			}
		}	
        
		if( $lookingFor -ne $null)
		{		 
			#If we haven't found the $Where yet, then we may have found it now.       
			if (! $foundWhere)
			{                                                        			     
				# We have found the $Where if it has the value we want.
				if ( [String]::Compare($valueWeFound, $Is, $true) -eq 0 )
				{								
					# Ok it has the value we want too.  Now, are we looking for a specific
					# sibling or child of this node or are we done here?
					if ($Return -eq $null)
					{
						#we are done, there is no $Return to look for
						print -displayName $Gpo.DisplayName -value $null;
						return;              
					}
					else
					{
						# Now lets look for $Return in the siblings and then if no go, the children.                      					  											
					   processNodes -nodes $node -foundWhere $true;                           						    		
					}
				}
               			
			}		
			else
			{
				#we are done.  We already found the $Where, and now we have found the $Return.
				print -displayName $Gpo.DisplayName -value $valueWeFound;
				return;   
			}
		}	   				    		   
				
		
		if (! [String]::IsNullOrEmpty($node.InnerXml))
		{					
			processNodes -nodes $node.ChildNodes -foundWhere $foundWhere;
		}    		
	}
}

#Import our module for the call to the Get-GPO cmdlet
Import-Module GroupPolicy;

$allGposInDomain = Get-GPO -All -Domain $DomainName;

$xmlnsGpSettings = "http://www.microsoft.com/GroupPolicy/Settings";
$xmlnsSchemaInstance = "http://www.w3.org/2001/XMLSchema-instance";
$xmlnsSchema = "http://www.w3.org/2001/XMLSchema";

$QueryString = "gp:";

if($IsComputerConfiguration){ $QueryString += "Computer/gp:ExtensionData/gp:Extension"; }
else{ $QueryString += "User/gp:ExtensionData/gp:Extension"; }

foreach ($Gpo in $allGposInDomain)
{				
	$xmlDoc = [xml] (Get-GPOReport -Guid $Gpo.Id -ReportType xml -Domain $Gpo.DomainName);		
	$xmlNameSpaceMgr = New-Object System.Xml.XmlNamespaceManager($xmlDoc.NameTable);

	$xmlNameSpaceMgr.AddNamespace("", $xmlnsGpSettings);
	$xmlNameSpaceMgr.AddNamespace("gp", $xmlnsGpSettings);
	$xmlNameSpaceMgr.AddNamespace("xsi", $xmlnsSchemaInstance);
	$xmlNameSpaceMgr.AddNamespace("xsd", $xmlnsSchema);

	$extensionNodes = $xmlDoc.DocumentElement.SelectNodes($QueryString, $XmlNameSpaceMgr);

	foreach ($extensionNode in $extensionNodes)
    	{				
		if ([String]::Compare(($extensionNode.Attributes.Item(0)).Value, 
			"http://www.microsoft.com/GroupPolicy/Settings/" + $Extension, $true) -eq 0)
		{
			# We have found the Extension we are looking for now recursively search
			# for $Where (the property we are looking for a specific value of).
																
			processNodes -nodes $extensionNode.ChildNodes -foundWhere $false;		
		}
	}		
}