function Install-Applications([string] $file)
{
    Write-Host "Installing Applications from $file"

    if ($env:packagesSource) {
        $packagesSource = "-s ""$env:packagesSource;chocolatey"""
    } 

    Invoke-Commands $file "choco install ##token## --execution-timeout=14400 -y $packagesSource"
}

function Uninstall-Applications([string] $file)
{
    Write-Host "Uninstalling Applications from $file"

    if ($env:packagesSource) {
        $packagesSource = "-s ""$env:packagesSource;chocolatey"""
    } 

    Invoke-Commands $file "choco uninstall ##token## --execution-timeout=14400 -y $packagesSource"
}

function Invoke-Commands([string] $file, [string] $commandTemplate) {
    try {
        foreach ($line in Get-Content -Path $file | Where-Object {$_.trim() -notmatch '(^\s*$)|(^#)'})
        {
            $commmand = $commandTemplate.replace("##token##", $line)

            Write-Host "Running: $commmand"

            Invoke-Expression $commmand
        }
    }
    catch {
         Write-Host "Failed: $($_.Exception.Message)"
    }
}

function Invoke-Executables([string] $path) {
    $exes = Get-ChildItem -Path $path -Filter *.exe -Recurse

    foreach ($e in $exes) {
        try {
            Write-Host "Running $e"

            & $e
        }
        catch {
            Write-Host "Failed Running: $e, Message: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember *