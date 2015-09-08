
# get the script folder to use as base, we do else when running headless the default folder is C:\windows\system32
$folder = Split-Path -parent $MyInvocation.MyCommand.Definition
# The $applicationpath is set via the RM process automatically to the local artifacts folder
# we use this as the DACBac base, the alternate is a relative path to the $folder
Write-Verbose "Deploying DACPAC '$ApplicationPath\$SOURCEFILE' to server '$TARGETSERVERNAME' as DB '$TARGETDATABASENAME'"
& $folder\sqlpackage.exe /Action:Publish /SourceFile:$ApplicationPath\$SOURCEFILE /TargetServerName:$TARGETSERVERNAME /TargetDatabaseName:$TARGETDATABASENAME /TargetUser:$TARGETUSER /TargetPassword:$TARGETPASSWORD | Write-Verbose -Verbose


