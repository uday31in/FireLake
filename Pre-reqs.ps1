# Cmdlets must be executed by a user with appropriate permission to enrollment and tenant root, and access to a subscription
# Assigning permissions to create subscriptions for service principal

$Enroll = Get-AzureRmEnrollmentAccount

$SPNName = "foobar"

$mgmtGroupRootScope = "/providers/Microsoft.Management/managementGroups/M2"

$SecureStringPassword = ConvertTo-SecureString -String "password" -AsPlainText -Force

# Creating Service Principal

New-AzureRmADServicePrincipal -DisplayName $SPNName -Password $SecureStringPassword -Scope "/providers/Microsoft.Management/managementGroups/ARMMSP" -Role "Owner" -Verbose 

$appId = Get-AzureRmADApplication | Where-Object {$_.DisplayName -eq $SPNName}

# Assign permission for Service Principal at root mgmt group scope

New-AzureRmRoleAssignment -RoleDefinitionName "Owner" -ApplicationId $appId.ApplicationId -Scope "/providers/Microsoft.Billing/enrollmentAccounts/$($Enroll.objectId)"

New-AzureRmRoleAssignment -RoleDefinitionName "Management Group Contributor" -ApplicationId $appId.ApplicationId -Scope $mgmtGroupRootScope -Verbose

New-AzureRmRoleAssignment -RoleDefinitionName "User Access Administrator" -ApplicationId $appId.ApplicationId -Scope $mgmtGroupRootScope -Verbose

# end