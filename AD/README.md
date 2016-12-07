# Active Directory Scripts

Here you will find scripts that change or query active directory objects in some way.

## Edit this Page to Include Usage and a Short Description for your Scripts

Please make sure to update this summary README.md file using MarkDown with the names of the scripts, sample usage, and a short description about the intended use.  
**Make sure you keep all accounts and domains needed as variables so that these wont be a security concern.**

##Scripts

###[Import-PicturesIntoAD.ps1](./Import-PicturesIntoAD.ps1)
* ####Example
Import-PicturesIntoAD -TargetDomain domain.root -LenelDB sqlserver01.domain.root\AccessControl -NumberOfUsers 200 -Verbose -force
* ####Description
This script will get users with EmployeeID and a Mailbox from the root domain while filtering for NLE and accounts that already have thumbnailPhoto attribute already populated.  Once done, it will get all accounts with EmployeeID from the Lenel DB and match the two to import the pictures from the badge system into AD. It will use a target domain, desired pixel size for the picture, and the number of users to process at one time.  The last two parameters are to keep the bandwidth use for replication to a manageable size.

###[Import-PicturesIntoExchange.ps1](./Import-PicturesIntoExchange.ps1)
* ####Example
Import-PicturesIntoExchange.ps1 -TargetDomain domain.root -LenelDB sqlserver01.domain.root\AccessControl -NumberOfUsers 200 -Verbose -force
* ####Description
This script will get users with EmployeeID and a Mailbox from the root domain and filter based on what's passed in or the default (mailbox exists, employeeID exists, thumbnailPhoto is not set)  ated.  Once done, it will get all accounts with EmployeeID from the Lenel DB and match the two to import the pictures from the badge system into Exchange. It will need a target domain, Lenel database, and the number of users to process at one time.

###[Next-ScriptGoesHere.ps1](./Next-ScriptGoesHere.ps1)
* ####Example
Script-Name -param1 values -param2 values -verbose -debug -whatif
* ####Description
The script does this and that. Input this. Output that...

