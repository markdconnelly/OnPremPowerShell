<#  This script assumes that you have cleaned and validated your data using the "ValidateUserListAgainstAD.ps1" script. There is limited
    error handling in this script. It is intended to be used with a clean list of users that have had their AD attributes extracted.

    This script will add users to a specified group. It will also create a log file that can be used to identify users that were not added to the group.
    The log file will contain the following information:
        - The user that was provided on the source list
        - The reason why the user was not added to the group
        - The raw error that was returned by the Add-ADGroupMember cmdlet

    $strGroupIdentity must be set. This variable is used for the Get-ADGroup cmdlet. It can be set to the following:
        - Distinguished Name
        - GUID
        - SID
        - SamAccountName
#>

####################### Variables Requiring Input #################
$strImportFilePath = "(Your Import File Here)"
$strExportDirPath = "(Your Export Directory Here)"
$strGroupIdentity = "(Your Group Display Name Here)"
###################### Variables Requiring Input ################# 

$arrResolvedUsers = @()
$arrResolvedUsers = Import-Csv -LiteralPath $strImportFilePath
$arrGroup = @()
$psobjGroupAddResults = @()
try {
    $arrGroup = Get-ADGroup -Identity $strGroupIdentity -Properties * -ErrorAction Stop
    $intProgressStatus = 1
    $arrUser = @()
    foreach($arrUser in $arrResolvedUsers){
        #   Progress Bar
        Write-Progress `
            -Activity "Adding Users to Group " + $strGroupIdentity `
            -Status "$($intProgressStatus) of $($arrResolvedUsers.Count)" `
            -CurrentOperation $intProgressStatus `
            -PercentComplete (($intProgressStatus / @($arrResolvedUsers).Count) * 100)
        $objError = ""
        #   Try/Catch - Add Users to Group
        try{
            Add-ADGroupMember -Identity $arrGroup.DistinguishedName -Members $arrUser.SamAccountName -ErrorAction Stop
            $psobjGroupAddResults += [PSCustomObject]@{
                UPN = $arrUser.UserPrincipalName
                SamAccountName = $arrUser.SamAccountName
                Operation = "Add-ADGroupMember"
                Group = $arrGroup.DistinguishedName
                Result = "Success"
                RawError = "N/A"
            }
        }catch{
            $objError = Get-Error
            $psobjGroupAddResults += [PSCustomObject]@{
                UPN = $arrUser.UserPrincipalName
                SamAccountName = $arrUser.SamAccountName
                Operation = "Add-ADGroupMember"
                Group = $arrGroup.DistinguishedName
                Result = "Failure"
                RawError = $objError
            }
        }
        $intProgressStatus++
    }
}
catch {
    Write-Host "Unable to resolve group: " + $strGroupIdentity
    Write-Host "Please check the value of the variable: $strGroupIdentity"
    Write-Host "Exiting script..."
    exit
}
#   export to file *clean up with real variables after finishing script
$dateNow = ""
$dateNow = Get-Date
$strFilePathDate = ""
$strFilePathDate = $dateNow.ToString("yyyyMMddhhmm")
$strOperationLog = ""
$strOperationLog = $strExportDirPath + $strGroupIdentity + "_BulkGroupAdd_" + $strFilePathDate + ".csv"
$intSuccessfulAdds = 0
$intFailedAdds = 0
$intSuccessfulAdds = $psobjGroupAddResults | Where-Object {$_.Result -eq "Success"} | Measure-Object | Select-Object -ExpandProperty Count
$intFailedAdds = $psobjGroupAddResults | Where-Object {$_.Result -eq "Failure"} | Measure-Object | Select-Object -ExpandProperty Count
Write-Host "Users that were successfully added: " + $intSuccessfulAdds
Write-Host "Users that were not added: " + $intFailedAdds
Write-Host "Exporting results to: " + $strOperationLog
$psobjGroupAddResults | ConvertTo-Csv | Out-File $strOperationLog