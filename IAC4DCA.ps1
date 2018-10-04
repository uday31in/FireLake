param
(
[switch] $MgmtandSubscriptions,
[switch] $RoleDefinition,
[switch] $RoleAssignment,
[switch] $PolicyDefinition,
[switch] $PolicyAssignment, 
[switch] $TemplateDeployment,

$AzureIsAuthoritative = $true,
$TenantRootId = 'b590c310-f80d-4c5b-981f-7dc9c87ea414',
$TenantRootname = 'root',
$TenantManagementGroupRoot = "M2",
$vstsAAObjectID = (Get-AzureRmADServicePrincipal -SearchString 'iaac4dcm-cd4dcm-M2').Id,
$mgmtSubscriptionID= "bb81881b-d6a7-4590-b14e-bb3c575e42c5",
[string]$managementgrouptofind = ""


)

if($env:BUILD_SOURCESDIRECTORY)
{
    Write-Host "VSTS"
    $path = "$env:BUILD_SOURCESDIRECTORY"

}
elseif ($($MyInvocation.ScriptName) -ne $null -and $($MyInvocation.ScriptName) -ne '')
{
    $path =  Split-Path $myInvocation.ScriptName 

}
else
{
    $path = $pwd
}


Write-Host "Using Current Path: $path"

Write-Host "BUILD_REPOSITORY_LOCALPATH: $env:BUILD_REPOSITORY_LOCALPATH"
Write-Host "BUILD_SOURCESDIRECTORY: $env:BUILD_SOURCESDIRECTORY"
Write-Host "falgDeleteIfNecessary : $falgDeleteIfNecessary"
Write-Host "pathtoManangementGroup : $pathtoManangementGroup"
Write-Host "mgmtSubscriptionPath: $mgmtSubscriptionPath"

Import-Module "$path\IAC4DCA.psm1" -Force


if($MgmtandSubscriptions)
{

    Write-Host "IAC4DCAMgmtandSubscriptions : $AzureIsAuthoritative"

    Ensure-AzureRMManagementAndSubscriptionHierarchy -AzureIsAuthoritative $AzureIsAuthoritative `
                                                        -TenantRootId $TenantRootId `
                                                        -TenantRootname $TenantRootname `
                                                        -MgmtRootFolderPath $path `
                                                        -vstsAAObjectID $vstsAAObjectID `
                                                        -mgmtSubscriptionID $mgmtSubscriptionID `
                                                        -managementgrouptofind $managementgrouptofind `                                                            
}

    
if($RoleDefinition)
{

    Write-Host "IAC4DCARoleDefintion : $AzureIsAuthoritative"
    Ensure-AzureRMRoleDefinition -AzureIsAuthoritative:$AzureIsAuthoritative -managementsubscriptionID $mgmtSubscriptionID -path $path\$TenantRootname\$TenantManagementGroupRoot
                                    
    
}
if($RoleAssignment)
{
    Write-Host "IAC4DCARoleAssignment : $AzureIsAuthoritative"
    Ensure-AzureRMRoleAssignment -AzureIsAuthoritative:$AzureIsAuthoritative -path $path\$TenantRootname\$TenantManagementGroupRoot
}

    
if($PolicyDefinition)
{
    Write-Host "IAC4DCAPolicyDefinitions : $AzureIsAuthoritative"
    Ensure-AzureRMPolicyDefinition -AzureIsAuthoritative:$AzureIsAuthoritative -path $path\$TenantRootname\$TenantManagementGroupRoot
    Ensure-AzureRMPolicySetDefinition -AzureIsAuthoritative:$AzureIsAuthoritative -path $path\$TenantRootname\$TenantManagementGroupRoot

}
if($PolicyAssignment)
{
    Write-Host "IAC4DCAPolicyAssignments : $AzureIsAuthoritative"
    Ensure-AzureRMPolicyAssignment -AzureIsAuthoritative:$AzureIsAuthoritative -path $path\$TenantRootname\$TenantManagementGroupRoot


}

    
if($TemplateDeployment)
{
    Write-Host "IAC4DCATemplateDeployment : $AzureIsAuthoritative"
    Ensure-AzureRMRGDeployment -AzureIsAuthoritative:$AzureIsAuthoritative -path $path\$TenantRootname\$TenantManagementGroupRoot


}