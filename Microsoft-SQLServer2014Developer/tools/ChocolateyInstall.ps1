﻿$updatedOn = 'BE70D2DE5F3E3A65BF2C0A2D2F91CC85C7C588579E89EA366408797B2E90D5D1'
$installerBase = 'Microsoft SQL Server 2014 Developer SP2'
$defaultConfigurationFile = Join-Path $env:chocolateyPackageFolder 'Configuration.ini'
$parameters = Get-Parameters $env:chocolateyPackageParameters
$configurationFile = Get-ConfigurationFile $parameters['ConfigurationFile'] $defaultConfigurationFile
$silentArgs = "/IAcceptSQLServerLicenseTerms /ConfigurationFile=""$($configurationFile)"""

if (-not $parameters.ContainsKey('sqlsysadminaccounts')) {
    $silentArgs = $silentArgs + " /SQLSYSADMINACCOUNTS=""$(whoami)"""
}

# The file is defined explictely so the update script can find it and embed it
$arguments = @{
    file           = 'Microsoft SQL Server 2014 Developer SP2.7z'
    destination    = $env:Temp
    executable     = "$installerBase\Setup.exe"
    silentArgs     = $silentArgs
    validExitCodes = @(2147781575, 2147205120)
}

# If the /file argument was specified, use the ISO to install
if ([System.IO.File]::Exists($parameters.file)) {
    $arguments.file = $parameters.file

    Install-FromIso $arguments
}
else {
    Install-FromZip $arguments

    Get-ChildItem $env:Temp -Filter $installerBase | Remove-Item -Recurse -Force
}