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

function Get-StoreDownloadLink ($distro) {
    # Uses $distro.StoreLink to get $distro.URI
    # Required when URI is not hard-coded
    #### Thanks to MattiasC85 for this excelent method of getting Microsoft Store download URIs ####
    # Source: https://github.com/MattiasC85/Scripts/blob/a1163b97875ed075927438505808622614a9961f/OSD/Download-AppxFromStore.ps1
    $wchttp=[System.Net.WebClient]::new()
    $URI = "https://store.rg-adguard.net/api/GetFiles"
    $myParameters = "type=url&url=$($distro.StoreLink)"
    $wchttp.Headers[[System.Net.HttpRequestHeader]::ContentType]="application/x-www-form-urlencoded"
    $HtmlResult = $wchttp.UploadString($URI, $myParameters)
    $Start=$HtmlResult.IndexOf("<p>The links were successfully received from the Microsoft Store server.</p>")
    if ($Start -eq -1) {
        write-host "Could not get Microsoft Store download URI, please check the StoreURL."
        exit
    }
    $TableEnd=($HtmlResult.LastIndexOf("</table>")+8)
    $SemiCleaned=$HtmlResult.Substring($start,$TableEnd-$start)
    $newHtml=New-Object -ComObject "HTMLFile"
    $src = [System.Text.Encoding]::Unicode.GetBytes($SemiCleaned)
    $newHtml.write($src)
    $ToDownload=$newHtml.getElementsByTagName("a") | Select-Object textContent, href
    $apxLinks = @()
    $ToDownload | Foreach-Object {
        if ($_.textContent -match '.appxbundle') {
            $apxLinks = $_
        }
    }
    $distro.URI = $apxLinks.href
    return $distro
}

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
