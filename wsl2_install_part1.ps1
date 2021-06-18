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

function Update-Kernel () {
    Write-Host(" ...Downloading WSL2 Kernel Update.")
    $kernelURI = 'https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi'
    $kernelUpdate = ((Get-Location).Path) + '\wsl_update_x64.msi'
    (New-Object System.Net.WebClient).DownloadFile($kernelURI, $kernelUpdate)
    Write-Host(" ...Installing WSL2 Kernel Update.")
    msiexec /i $kernelUpdate /qn
    Start-Sleep -Seconds 5
    Write-Host(" ...Cleaning up Kernel Update installer.")
    Remove-Item -Path $kernelUpdate
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



function Check-Sideload (){
    # Return $true if sideloading is enabled
    $keyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    $Key = Get-Item -LiteralPath $keyPath
    $sideloadKeys = @("AllowAllTrustedApps", "AllowDevelopmentWithoutDevLicense")
    $return = $true
    function Test-RegProperty ($propertyname){
        if (($Key.GetValue($propertyname, $null)) -ne $null){
            return $true
        } else {
            return $false
        }
    }
    $sideloadKeys | ForEach-Object {
        if (!(Test-RegProperty ($_))){
            $return = $false
        } else {
            if (( (Get-ItemProperty -Path $keyPath -Name $_).$_ ) -ne 1 ){
                $return = $false
            }
        }
    }
    return $return
}
function Enable-Sideload () {
    # Allow sideloading of unsigned appx packages
    $keyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock"
    if (!(Test-Path -Path $keyPath)){
        New-Item -Path $keyPath # In case the entire registry key was accidentally deleted
    }
    $Key = Get-Item -LiteralPath $keyPath
    $sideloadKeys = @("AllowAllTrustedApps", "AllowDevelopmentWithoutDevLicense")
    function Test-RegProperty ($propertyname){
        if (($Key.GetValue($propertyname, $null)) -ne $null){
            return $true
        } else {
            return $false
        }
    }
    $sideloadKeys | ForEach-Object {
        if (!(Test-RegProperty $_)){
            New-ItemProperty -Path $keyPath -Name $_ -Value "1" -PropertyType DWORD -Force | Out-Null
        } else {
            Set-ItemProperty -Path $keyPath -Name $_ -Value "1" -PropertyType DWORD -Force | Out-Null
        }
    }
}


if ($rebootRequired) {
    shutdown /t 120 /r /c "Reboot required to finish installing WSL2"
    }
} else {
    if (!(Get-Kernel-Updated)) {
        Write-Host(" ...WSL kernel update not installed.")
        Update-Kernel
    } else {
        Write-Host(" ...WSL update already installed.")
    }
    }
