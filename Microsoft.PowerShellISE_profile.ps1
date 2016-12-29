Set-StrictMode -Version Latest
$LASTEXITCODE = 0

if (Get-Command *Install-Module){
    Install-Module -Name PowerShellCookBook -Scope CurrentUser -Force
}

function Test-Administrator {
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

if (Test-Administrator){
    $env:RunningAsAdmin = $true
}

if ($env:RunningAsAdmin){
	$host.ui.rawui.WindowTitle = "* ADMINISTRATOR * " + $env:USERNAME + " PC: " + $Env:COMPUTERNAME + " v" + $Host.Version + " - " + $env:PROCESSOR_ARCHITECTURE
	Write-Host "`t`t******************************************************" -ForegroundColor Red
	Write-Host "`t`t******** Running as administrator on this box. *******" -ForegroundColor Red
	Write-Host "`t`t******************************************************" -ForegroundColor Red
} else {
	$host.ui.rawui.WindowTitle = $env:USERNAME + " " + $Env:COMPUTERNAME + " v" + $Host.Version + " - " + $env:PROCESSOR_ARCHITECTURE
}

Function Prompt {
    $realLASTEXITCODE = $LASTEXITCODE

    Write-Host

    # Reset color, which can be messed up by other modules
    $Host.UI.RawUI.ForegroundColor = "White"


    if ($env:RunningAsAdmin) {  # Use different username if elevated
        Write-Host "(Elevated) " -NoNewline -ForegroundColor Red
    }

    Write-Host "$ENV:USERNAME@" -NoNewline -ForegroundColor DarkYellow

    if (Test-Path variable:PSSenderInfo) {  # color for PSSessions
        $s = $PSSenderInfo.ConnectionString.Substring(7,($PSSenderInfo.ConnectionString.IndexOf(":",7) - 7))
        Write-Host "(" -NoNewline -ForegroundColor DarkGray
        Write-Host "$($s)" -NoNewline -ForegroundColor Yellow
        Write-Host ") " -NoNewline -ForegroundColor DarkGray
    }

    Write-Host " : " -NoNewline -ForegroundColor DarkGray
    Write-Host $($(Get-Location) -replace ($env:USERPROFILE).Replace('\','\\'), "~") -NoNewline -ForegroundColor Cyan
    Write-Host " : " -NoNewline -ForegroundColor DarkGray
    Write-Host $(Get-Date -Format G) -NoNewline -ForegroundColor DarkMagenta
    Write-Host " : " -NoNewline -ForegroundColor DarkGray

    $global:LASTEXITCODE = $realLASTEXITCODE

    if(get-module posh-git){
        Write-VcsStatus
    }
    Write-Host ""

    return "> "
}

#add envronment variables for the path to SCCM and vSphere modules.
If (Test-Path Env:SMS_ADMIN_UI_PATH){$Env:ConfigManager = ((Get-Item -Path $Env:SMS_ADMIN_UI_PATH).Parent.FullName + "\ConfigurationManager.psd1")}
If (Test-Path "hklm:\Software\wow6432node\VMware, Inc.\VMware vSphere PowerCLI"){$Env:vSpherePath = (Get-ItemProperty "hklm:\Software\wow6432node\VMware, Inc.\VMware vSphere PowerCLI" -ErrorAction SilentlyContinue).InstallPath}
If (Test-Path "hklm:\Software\VMware, Inc.\VMware vSphere PowerCLI"){$Env:vSpherePath = (Get-ItemProperty "hklm:\Software\VMware, Inc.\VMware vSphere PowerCLI" -ErrorAction SilentlyContinue).InstallPath}
If (Test-Path Env:vSpherePath){ $Env:vSphereCLI = Join-Path $Env:vSpherePath "Scripts\Initialize-PowerCLIEnvironment.ps1"}

#add PSDrives to all module paths in the system.
New-PSDrive -Name MyMods -PSProvider filesystem -Root (($env:PSModulePath).Split(";")[0])
New-PSDrive -Name SysMods -PSProvider filesystem -Root (($env:PSModulePath).Split(";")[1])

#add my ISE functions module
If (-not (Get-Module PoShScripting)){
	Import-module MyMods:\MyModules\PoShScripting.psm1
}

#add replace 4 spaces with tabs
if (!($psISE.CurrentPowerShellTab.AddOnsMenu.Submenus | Where-Object { $_.DisplayName -eq "Spaces to Tabs" }))
{
	$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Spaces to Tabs",{Convert-SpacesToTabs -RemoveExtraLines},"Ctrl+Alt+T")
}

# Add a block comment and uncomment menu items.
If (-not (Get-Module ISEAddOns)){
	Import-module MyMods:\MyModules\ISEAddOns.psm1
}

if (!($psISE.CurrentPowerShellTab.AddOnsMenu.Submenus | Where-Object { $_.DisplayName -eq "Block Comment" }))
{
	$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Block Comment",{Add-ISEComment},"Ctrl+K")
}
if (!($psISE.CurrentPowerShellTab.AddOnsMenu.Submenus | Where-Object { $_.DisplayName -eq "Block Uncomment" }))
{
	$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add("Block Uncomment",{Remove-ISEComment},"Ctrl+Shift+K")
}

. MyMods:\MyModules\Get-ChildItem-Color.ps1
Set-Alias ll Get-ChildItem-Color -Option AllScope -Force
Set-Alias ls Get-ChildItem-Format-Wide -Option AllScope -Force
Set-Alias la Get-ChildItem-All -Option AllScope -Force
Set-Alias dir Get-ChildItem-Color -Option AllScope -Force

$plink = "C:\Users\me14114\AppData\Local\Microsoft\AppV\Client\Integration\F8162E1C-DD55-4CF5-B570-73758CD0B08E\Root\plink.exe"

function Fake-SSH{
PARAM()
    $New_Args = "-ssh -2"
    $args | %{ $New_Args = $New_Args + " " + $_}

    Write-Output "$plink $New_Args"
    Invoke-Expression "$plink $New_Args"

}

$MaximumHistoryCount = 1KB


if (!(Test-Path ~\PowerShell -PathType Container))
{
    New-Item ~\PowerShell -ItemType Directory
}

function bye 
{
    Get-History -Count 1KB |Export-CSV ~\PowerShell\history.csv
    exit
}

if (Test-path ~\PowerShell\History.csv)
{
    Import-CSV ~\PowerShell\History.csv |Add-History
}
