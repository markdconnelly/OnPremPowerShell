<#  This script is designed to take a list of users and compare them against Active Directory. It will then export the results to two different files.
    One file will contain details about the users that were successfully resolved and the other will contain details about the users that were not resolved.
    These outputs can then be used to identify users that were provided on the source list but are not in Active Directory.
    The Resolved Users output can then be used in conjunction with other scripts to perform tasks like bulk group adds or bulk group removals etc with 
    valid users.    
    
    This script is based on the -Identity parameter of the Get-ADUser cmdlet. It will attempt to resolve the user based on the value provided in the UserID field
    These can include: 
        - Distinguished Name
        - GUID
        - SID
        - SamAccountName
    #>
####################### Variables Requiring Input #################
$strImportFilePath = "(Your Import File Here)"
$strExportDirPath = "(Your Export Directory Here)"
$strBatchJobName = "(Your Batch Job Name Here)"
###################### Variables Requiring Input ################# 
$arrImportedUsers = Import-Csv -LiteralPath $strImportFilePath
$arrUser = @()
$intProgressStatus = 1
$psobjResolvedUsers = @()
$psobjUnresolvedUsers = @()
foreach($arrUser in $arrImportedUsers){
    $objError = ""
    $arrGetADUser = @()
    #   Progress Bar
    Write-Progress `
        -Activity "Checking Users Against AD" `
        -Status "$($intProgressStatus) of $($arrImportedUsers.Count)" `
        -CurrentOperation $intProgressStatus `
        -PercentComplete  (($intProgressStatus / @($arrImportedUsers).Count) * 100)
    #   Try/Catch - Resolve Users

    try{
        $arrGetADUser = Get-ADUser -Identity $arrUser.UserID -ErrorAction Stop
        $psobjResolvedUsers += [PSCustomObject]@{
            SamAccountName = $arrGetADUser.SamAccountName
        }       
    }catch{
        $objError = Get-Error
        $psobjUnresolvedUsers += [PSCustomObject]@{
            ProvidedName = $arrUser.UserID
            FailureReason = "Unable to resolve"
            RawError = $objError
        } 
    }
    $intProgressStatus ++
}
#   export to file
$dateNow = Get-Date 
$strFilePathDate = $dateNow.ToString("yyyyMMddhhmm")
$strResolvedUserFilePath = $strExportDirPath + $strBatchJobName + "Resolved_Users_" + $strFilePathDate + ".csv"
$strUnresolvedUserFilePath = $strExportDirPath + $strBatchJobName + "Unresolved_Users_" + $strFilePathDate + ".csv"
Write-Host "Resolved Users: " + $psobjResolvedUsers.Count
Write-Host "Unresolved Users: " + $psobjUnresolvedUsers.Count
$psobjUnresolvedUsers | ConvertTo-Csv | Out-File $strUnresolvedUserFilePath
$psobjResolvedUsers | ConvertTo-Csv | Out-File $strResolvedUserFilePath