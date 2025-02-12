$excludeFiles = $('update.ps1', 'chocolateyInstall.ps1', '*.nupkg', '*.nuspec')

$global:au_Force = $false

# packageDir is defined in the individual update script
Push-Location $packageDir

$installersPath = Join-Path $PSScriptRoot '..\..\..\BoxStarter\Installers' -Resolve
$packageInstallerDir = @{$true = $global:au_packageInstallerDir; $false = "$packageDir\tools"; }[(Test-Path variable:\au_packageInstallerDir)]

$global:au_isFixedVersion = @{$true = $global:au_isFixedVersion; $false = $false; }[(Test-Path variable:\au_isFixedVersion)]

$programsSettingsDir = Join-Path $PSSCriptRoot '..\..\..\Programs\Settings' -Resolve
$packageName = (Split-Path -Leaf $packageDir) -replace '-Personal'

$downloadsFile = Join-Path $PSSCriptRoot '.\Downloads.txt' -Resolve

# settingsZip is the package.zip by default,
# but can be overridden in the individual update script
$settingsZip = "$packageName.zip"

# settingsDir is the package directory by default,
# but can be overridden in the individual update script
$settingsDir = @{$true = $global:au_settingsDir; $false = $packageDir; }[(Test-Path variable:\au_settingsDir)]

# Find the saved settings directory for the package
$savedSettingsDir = Get-ChildItem -Path $programsSettingsDir -Directory -Filter $packageName | Select-Object -First 1 -ExpandPropert FullName

function global:au_BeforeUpdate {
    if ($Latest.FileName32) {
        $installer = $Latest.FileName32
        Write-Host "Setting installer, Lastest.Filename32: $($Lastest.Filename32)"
    }
    elseif ($Latest.Url32) {
        $installer = [System.IO.Path]::GetFileName($Latest.Url32) -replace '%20', ' '
        Write-Host "Setting installer, Lastest.Url32: $installer"
    }
    else {
        $installer = (Get-Item $packageDir\tools\ChocolateyInstall.ps1 | Select-String "(?i)file\s*=\s*'.*'" | Select-Object -First 1) -Split "=|'" | Select-Object -Last 1 -Skip 1
        Write-Host "Setting installer, ChocolateyInstall.ps1: $installer"
    }

    $existingInstaller = Join-Path $installersPath $installer

    $localVersion = $Latest.NuspecVersion
    $remoteVersion = $Latest.Version
    $installerFile = [System.IO.Path]::GetFileName($installer)
    $existingInstallerFile = [System.IO.Path]::GetFileName($existingInstaller)

    if (((-not(Test-Path $existingInstaller) -and $Latest.Url32) -or $localVersion -ne $remoteVersion) `
            -and ($Latest.PackageName -notmatch '\-Personal$|PowerShell-Helpers')) {
        if (-not(Test-Path $existingInstaller)) {
            Write-Host "No Existing Installer: $existingInstaller"
        }
        elseif ($localVersion -ne $remoteVersion) {
            Write-Host "Local Version and Remote Differ..."
        }

        $Latest.Url32 | Tee-Object $downloadsFile -Append | Write-Output
        $Latest.FileName32 = [System.IO.Path]::GetFileName($Latest.Url32)
        <#
        # Use the AU function to get the installer
        # Write-Host "Getting Installer with Get-RemoteFiles"
        Get-RemoteFiles -NoSuffix `
            -FileNameBase $([System.IO.Path]::GetFileNameWithoutExtension($existingInstaller))

        # Find the downloaded file
        $downloadedFile = Get-ChildItem `
            -Recurse *.7z, *.zip, *.tar.gz, *.exe, *.msi, *.jar | Select-Object -First 1
        Write-Host "Installer Downloaded: $downloadedFile"

        # Remove the any HTML encoded space
        $installer = Join-Path $packageInstallerDir ((Split-Path -Leaf $downloadedFile) -replace '%20', ' ')
        $installer = [System.IO.Path]::GetFileName($installer)

        $Latest.FileName32 = $installer
        #>
        $Latest.UpdateInstaller = $true

        Write-Host "
Installer: $installer
Latest.FileName32: $($Latest.FileName32)
Latest.UpdateInstaller: $($Latest.UpdateInstaller)"
    }
    elseif (Test-Path $existingInstaller) {
        $Latest.Checksum32 = (Get-FileHash $existingInstaller).Hash
        $Latest.FileName32 = $installer
        Write-Host "
Existing Installer: $existingInstaller
Latest.Checksum: $($Latest.Checksum32)
Latest.FileName32: $($Latest.FileName32)"
    }

    if ($settingsDir -ne $packageDir) {
        Compress-Archive `
            -Path $($Latest.SettingsDir) `
            -DestinationPath $settingsZip `
            -Force
    }

    global:au_CleanUp
}

function global:au_GetLatest {
    if ($savedSettingsDir) {
        $settingsDir = $savedSettingsDir
    }

    # Get the version from the nuspec
    $version = (Get-Item "$($Latest.PackageName).nuspec" `
            | Select-String "(?i)<version>([0-9\.]+)</version>") `
        | ForEach-Object { $_.Matches[0].Groups[1].Value }

    # Force the version to be the same by default
    $global:au_Version = $version

    $fileName32 = (Get-Item $packageDir\tools\chocolateyInstall.ps1 | Select-String "(?i)file\s*=\s*'.*'" | Select-Object -First 1) -Split "=|'" | Select-Object -Last 1 -Skip 1
    $url = (Get-Item $packageDir\tools\chocolateyInstall.ps1 | Select-String "(?i)url\s*=\s*'.*'") -Split "=|'" | Select-Object -Last 1 -Skip 1
    $checksum = (Get-Item $packageDir\tools\chocolateyInstall.ps1 | Select-String "(?i)checksum\s*=\s*'.*'") -Split "=|'" | Select-Object -Last 1 -Skip 1

    try {
        # Get the last updated on date from the ChocolateyInstall file
        $updatedOn = [DateTime]((Get-Item $packageDir\tools\ChocolateyInstall.ps1 | Select-String "(?i)^[$]updatedOn\s*=\s*'.*'") -Split "=|'" | Select-Object -Last 1 -Skip 1)
    }
    catch {
        $updatedOn = get-date
    }

    # Get a list of updated files after the last updated on date
    $updatedFiles = Get-ChildItem $settingsDir -Recurse -File -Exclude $excludeFiles | Where-Object { $_.LastWriteTime -ge $updatedOn }

    if (($updatedFiles -or $force) -and (-not $global:au_isFixedVersion)) {
        $newVersion = ([version]$version)

        try {
            $newVersion = [DateTime]$version
            $newVersion = (Get-Date).ToString('yyyy.MM.dd')
        }
        catch {
            $newVersion = "$($newVersion.Major).$($newVersion.Minor).$($newVersion.Build + 1)"
        }

        $updatedOn = get-date
        $version = $newVersion
        $global:au_Version = $newVersion
        $global:au_Force = $true
    }

    $latestData = @{
        SettingsDir     = $settingsDir
        UpdatedOn       = $updatedOn.ToString('yyyy.MM.dd HH:mm:ss')
        UpdateInstaller = $false
        Version         = $version
    }

    if ($fileName32) { $latestData.FileName32 = $fileName32 }
    if ($url) { $latestData.Url32 = $url }
    if ($checksum) { $latestData.Checksum32 = $checksum }

    return $latestData
}

function global:au_SearchReplace {
    if (-not (Test-Path (Join-Path $packageDir 'tools\chocolateyInstall.ps1'))) {
        return @{}
    }

    $searchReplace = @{
        ".\tools\chocolateyInstall.ps1" = @{}
    }

    $file = (Get-Item $packageDir\tools\chocolateyInstall.ps1 | Select-String "(?i)file\s*=\s*'.*'" | Select-Object -First 1) -Split "=|'" | Select-Object -First 1
    $url = (Get-Item $packageDir\tools\chocolateyInstall.ps1 | Select-String "(?i)url\s*=\s*'.*'") -Split "=|'" | Select-Object -First 1
    $checksum = (Get-Item $packageDir\tools\chocolateyInstall.ps1 | Select-String "(?i)checksum\s*=\s*'.*'") -Split "=|'" | Select-Object -First 1
    $updatedOn = (Get-Item $packageDir\tools\ChocolateyInstall.ps1 | Select-String "(?i)^[$]updatedOn\s*=\s*'.*'") -Split "=|'" | Select-Object -First 1

    if ($file) { $searchReplace[".\tools\chocolateyInstall.ps1"]["(?i)(file\s*=\s*)('.*')"] = "`$1'$($Latest.FileName32)'" }
    if ($url) { $searchReplace[".\tools\chocolateyInstall.ps1"]["(?i)(url\s*=\s*)('.*')"] = "`$1'$($Latest.Url32)'" }
    if ($checksum) { $searchReplace[".\tools\chocolateyInstall.ps1"]["(?i)(checksum\s*=\s*)('.*')"] = "`$1'$($Latest.Checksum32)'" }
    if ($updatedOn) { $searchReplace[".\tools\chocolateyInstall.ps1"]["(?i)(^[$]updatedOn\s*=\s*)('.*')"] = "`$1'$($Latest.UpdatedOn)'" }

    return $searchReplace
}

function global:au_CleanUp {
    # Only cleanup if this is not a personal package
    if ($Latest.PackageName -notmatch '\-Personal$') {
        $packageInstaller = Join-Path $packageInstallerDir $Latest.FileName32
        $existingPackageInstaller = Join-Path $installersPath $Latest.FileName32

        if (((Test-FileExists $packageInstaller) -and (-not (Test-FileExists $existingPackageInstaller))) -or $Latest.UpdateInstaller) {
            # Get the beggining of the installer name, without the version
            $installer = $packageInstaller -replace '.*\\([a-z0-9]+).*$', '$1'

            # Delete any previous versions of the same installer
            # Get-ChildItem $installersPath -File | `
            # Where-Object { $_.Name -match $installer } | Remove-Item

            if (Test-FileExists $packageInstaller) {
                Write-Host "Moving '$packageInstaller' --> '$installersPath'"
                Move-Item $packageInstaller $installersPath -Force
            }
        }
    }
}