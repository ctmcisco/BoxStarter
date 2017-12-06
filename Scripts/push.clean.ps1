$packagesDir = Join-Path $PSScriptRoot '..\..\BoxStarter' -Resolve

$packages = @{}
$duplicatePackages = @()


Get-PublishedPackages | Sort-Object CreationTime -Descending | ForEach-Object {
    $packageName = $_ -replace '(.*?)\.([0-9\.]+).nupkg', '$1'

    if ($packages.ContainsKey($packageName)) {
        $duplicatePackages += $_
    }
    else {
        $packages[$packageName] += $_
    }
}

$duplicatePackages | ForEach-Object {
    Write-Host "Removing $_"
    Remove-Item (Join-Path $packagesDir $_) -Force | Out-Null
}