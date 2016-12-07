if (Get-Module ActiveDirectory) {
    
}

$dhcpservers = @{}

(Get-ADObject -SearchBase "CN=NetServices,CN=Services,CN=Configuration,DC=root,DC=ad" -Filter "objectclass -eq 'dhcpclass' -AND Name -ne 'dhcproot'").Name |  #check the root.ad domain
    %{ 
        If (Test-Connection -Quiet -Count 1 -ComputerName $_){
            $dhcpservers+= @{"$_"= "Online"}
        } else {
            $dhcpservers+= @{"$_"= "Offline"}
        }
    }
