Set-StrictMode -Version Latest
$LASTEXITCODE = 0

Install-Module -Name PowerShellCookBook -Scope CurrentUser

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
    $Host.UI.RawUI.BackgroundColor = "DarkMagenta"


    if ($env:RunningAsAdmin) {  # Use different username if elevated
        Write-Host "(Elevated) " -NoNewline -ForegroundColor Red
    }

    Write-Host "$ENV:USERNAME@" -NoNewline -ForegroundColor DarkYellow
    Write-Host "$ENV:COMPUTERNAME" -NoNewline -ForegroundColor Magenta

    if (Test-Path variable:PSSenderInfo) {  # color for PSSessions
        $s = $PSSenderInfo.ConnectionString.Substring(7,($PSSenderInfo.ConnectionString.IndexOf(":",7) - 7))
        Write-Host "(" -NoNewline -ForegroundColor DarkGray
        Write-Host "$($s)" -NoNewline -ForegroundColor Yellow
        Write-Host ") " -NoNewline -ForegroundColor DarkGray
    }

    Write-Host " : " -NoNewline -ForegroundColor DarkGray
    Write-Host $($(Get-Location) -replace ($env:USERPROFILE).Replace('\','\\'), "~") -NoNewline -ForegroundColor Cyan
    Write-Host " : " -NoNewline -ForegroundColor DarkGray
    Write-Host $(Get-Date -Format G) -NoNewline -ForegroundColor DarkGray
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

. MyMods:Get-ChildItem-Color.ps1
Set-Alias ll Get-ChildItem-Color -Option AllScope -Force
Set-Alias ls Get-ChildItem-Format-Wide -Option AllScope -Force
Set-Alias la Get-ChildItem-All -Option AllScope -Force
Set-Alias dir Get-ChildItem-Color -Option AllScope -Force
