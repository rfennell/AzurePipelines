function Get-VersionName {
param (
    $Format,
    $Version
)

    $VersionNumberSplit = $Version.Split('.')

    $VersionNameMatches = $Format | Select-String -Pattern '\d' -AllMatches
    $VersionName = ($VersionNameMatches.Matches.value | Foreach-Object {$VersionNumberSplit[$_ - 1]}) -join '.'
    return $VersionName

}

function Get-VersionCode {
    param (
        $Format,
        $Version
    )
    
    $VersionCodeSplit = $Version.Split('.')
    
    $VersionCodeMatches = $Format | Select-String -Pattern '\d' -AllMatches
    $VersionCode = ($VersionCodeMatches.Matches.value | Foreach-Object {$VersionCodeSplit[$_ - 1]}) -join ''
    return $VersionCode

}     
function Update-ManifestFile{
   param (
       $filename,
       $versionCode,
       $versionName

   )

   $Content = Get-Content $filename -Raw
   
   $Content = $Content -Replace 'VersionCode="\d+',"versionCode=`"$VersionCode"
   $Content = $Content -replace 'versionName="(\d+\.\d+){1,}',"versionName=`"$VersionName"

   $Content | Set-Content -Path $filename
}