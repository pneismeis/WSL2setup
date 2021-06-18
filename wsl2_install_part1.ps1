# Install WSL
# This script needs to be run as a priviledged user

Write-Host("Checking for Windows Subsystem for Linux...")
$rebootRequired = $false
if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux).State -ne 'Enabled'){
    Write-Host(" ...Installing Windows Subsystem for Linux.")
    $wslinst = Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName Microsoft-Windows-Subsystem-Linux
    if ($wslinst.Restartneeded -eq $true){
        $rebootRequired = $true
    }
} else {
    Write-Host(" ...Windows Subsystem for Linux already installed.")
}

Write-Host("Checking for Virtual Machine Platform...")
if ((Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform).State -ne 'Enabled'){
    Write-Host(" ...Installing Virtual Machine Platform.")
    $vmpinst = Enable-WindowsOptionalFeature -Online -NoRestart -FeatureName VirtualMachinePlatform
    if ($vmpinst.RestartNeeded -eq $true){
        $rebootRequired = $true
    }
} else {
    Write-Host(" ...Virtual Machine Platform already installed.")
}

function Get-Kernel-Updated () {
    # Check for Kernel Update Package
    Write-Host("Checking for Windows Subsystem for Linux Update...")
    $uninstall64 = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall" | ForEach-Object { Get-ItemProperty $_.PSPath } | Select-Object DisplayName, Publisher, DisplayVersion, InstallDate
    if ($uninstall64.DisplayName -contains 'Windows Subsystem for Linux Update') {
        return $true 
    } else {
        return $false
    }
}

$pkgs = (Get-AppxPackage).Name

function Get-WSLlist {
    $wslinstalls = New-Object Collections.Generic.List[String]
    $(wsl -l) | ForEach-Object { if ($_.Length -gt 1){ $wslinstalls.Add($_) } }
    $wslinstalls = $wslinstalls | Where-Object { $_ -ne 'Windows Subsystem for Linux Distributions:' }
    return $wslinstalls
}
function Get-WSLExistance ($distro) {
    # Check for the existence of a distro
    # return Installed as Bool
    $wslImport = $false
    if (($distro.AppxName).Length -eq 0){ $wslImport = $true }
    $installed = $false
    if ( $wslImport -eq $false ){
        if ($pkgs -match $distro.AppxName) {
            $installed = $true
        }
    } else {
        if (Get-WSLlist -contains ($distro.Name).Replace("-", " ")){
            $installed = $true
        }
    }
    return $installed
}
