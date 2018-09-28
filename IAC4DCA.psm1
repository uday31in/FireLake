#Requires -Modules @{ModuleName="AzureRm.Resources";ModuleVersion="6.5.0"}


if (Get-Module -ListAvailable -Name AzureRM.Subscription) {
    Write-Host "Module exists - Subscription"
} else {

   Install-Module -Name AzureRM.Subscription -Force -Verbose -Scope CurrentUser 
   
}

if (Get-Module -ListAvailable -Name AzureRM.Billing) {
    Write-Host "Module exists - Billing"
} else {

  
   Install-Module -Name Azurerm.Billing -Force -Verbose -Scope CurrentUser
   
}

if (Get-Module -ListAvailable -Name AzureRm.Resources) {
    Write-Host "Module exists - AzureRm.Resource"
} else {

  
   Install-Module -Name Azurerm.Resources -Force -Verbose -Scope CurrentUser
   
}



Import-Module AzureRM.ManagementGroups -Force



function Move-LocalManagementGroupParentToSameAsInAzure(
    [string] $managementgroupname = "",        
    [string] $managementgrouplocalfolderpath = "",
    [string] $parentmanagementgroupinazure = ''
) {
 
    $currentManagementGroup = (Get-ChildItem -Recurse -Directory -Path $managementgrouplocalfolderpath |? {$_.Name -eq $managementgroupname}).FullName
    $desiredMangementGroupPath = (Get-ChildItem -Recurse -Directory -Path $managementgrouplocalfolderpath |? { $_.Name  -eq $parentmanagementgroupinazure}).FullName

    Move-Item -Path $currentManagementGroup -Destination $desiredMangementGroupPath

}

function IsLocalManagementGroupParentSameAsInAzure(
    [string] $managementgroupname = "",
    [string] $parentmanagementgroupname = ""
) {
    
    $currentManagementGroup = (Get-ChildItem -Recurse -Directory -Path $folderpath |? {$_.Name -eq $managementgroupname})

    if ( $currentManagementGroup.Parent.Name -ne $parentmanagementgroupname -and
        $parentmanagementgroupname -ne ""
        ) {
        return $false
    }
    else {
        return $true
    }
}


function CreateLocalManagementGroupFolder(
    [string] $managementgroupname = "",
    [string] $parentmanagementgroupname = "",
    [string] $folderpath = ""
    #[string] $folderpath = (join-path -Path $MgmtRootFolderPath -ChildPath $TenantRootId )
)
{
    if($parentmanagementgroupname -ne "")
    {
        $desiredParentFolderPath =  (Get-ChildItem -Recurse -Directory -Path $folderpath |? { $_.Name  -eq $parentmanagementgroupname}).FullName
       
    }
    else {
        $desiredParentFolderPath =  (Get-Item -Path $folderpath).FullName
    }

    if($desiredParentFolderPath -eq $null)
    {
       Write-Host "Error"
    }
    else {
        mkdir $desiredParentFolderPath\$managementgroupname -Force -Confirm:$false | out-null
    }

}

function  IsLocalManagementGroupExist(
    [string] $managementgroupname = "",
    [string] $folderpath = (join-path -Path $MgmtRootFolderPath -ChildPath $TenantRootId )
) {
    
    if ( (Get-ChildItem -Recurse -Directory -Path $folderpath |? {$_.Name -eq $managementgroupname}).count -eq 1) {

        return $true
    }
    else {
        return $false
    }

}

function NormalizeName([string] $id )
{
    return ($id -split '/' | select -Last 1)
}

function EnsureLocalManagementGroupStructure (  $managementgroup, $parentname,  
                                                $folderpath = (join-path -Path $MgmtRootFolderPath -ChildPath $TenantRootId)
                                             )
{

    if(IsLocalManagementGroupExist -managementgroupname $managementgroup.DisplayName -folderpath $folderpath )
    {
        #Local Folder exist, check for parent relationship exist
        if(-not (IsLocalManagementGroupParentSameAsInAzure -managementgroupname $managementgroup.DisplayName  -parentmanagementgroupname $parentname ))
        {               
            #Move Management Group
            Move-LocalManagementGroupParentToSameAsInAzure  -managementgroupname   $managementgroup.DisplayName `
                                                            -parentmanagementgroupinazure   $parentname  `
                                                            -managementgrouplocalfolderpath $folderpath
        }               
    }
    else
    {
        #Create Local Folder for Management Group. Parent will always exist as a result of TraverseManagementGroupHeirarchy
        CreateLocalManagementGroupFolder -managementgroupname $managementgroup.DisplayName  `
                                         -parentmanagementgroupname $parentname `
                                         -folderpath $folderpath
    }    

    #Find Folder 
    $metadatapath = (Get-ChildItem -Path $folderpath -Directory -Recurse |? { $_.Name -eq $managementgroup.DisplayName }).FullName
    
    if($managementgroup.Type -eq '/subscriptions'){

        #Write Subscription Metadata
        Get-AzureRmSubscription -SubscriptionId  $managementgroup.Name | ConvertTo-Json -Depth 100 | Out-File "$metadatapath\subscription.json"
    }
    else {

        #Write Management Group Metadata
        Get-AzureRmManagementGroup -GroupName $managementgroup.Name | ConvertTo-Json -Depth 100 | Out-File "$metadatapath\managementgroup.json"
    }
}

function TraverseManagementGroupHeirarchy( $mgmtgroup , $parentname = $null) {
    
    Write-Host "Current Path: $($mgmtgroup.Id)"
    
    if ($mgmtgroup.name -eq $TenantRootId )
    {
        #if it is Tenant root management group
        EnsureLocalManagementGroupStructure -managementgroup $mgmtgroup -folderpath $MgmtRootFolderPath 
        #LocalTemp123 -managementgroup $mgmtgroup
    }
    else
    {
        EnsureLocalManagementGroupStructure -managementgroup $mgmtgroup -parentname $ParentName -folderpath $MgmtRootFolderPath 
        #LocalTemp123 -managementgroup $mgmtgroup
    }    
    
    foreach ($children in $mgmtgroup.Children)
    {

         TraverseManagementGroupHeirarchy -mgmtgroup $children -parentname $mgmtgroup.DisplayName

    
    }
}

function IsManagementGroupExistInAzure ([string]$managementgroupname)
{

    if (($Global:AzureRmManagementGroup |? {$_.DisplayName -eq $managementgroupname}).count -eq 1)
    {
        return $true
    }
    return $false
}
function IsManagementGroupParentMatchInAzure ([string]$managementgroupname, [string]$parentmanagemengroupname)
{
    if ( ($Global:AzureRmManagementGroup |? {$_.DisplayName -eq $managementgroupname}).count -eq 1  )
    {
        $managementgroup = $Global:AzureRmManagementGroup |? {$_.DisplayName -eq $managementgroupname}
        
        if($managementgroup.ParentDisplayName  -eq $parentmanagemengroupname -or 
           (-not ($managementgroup.parentId))
        )
        {
            return $true
        }
        else {
            return $false
        }
    }
    return $false    
}


function IsSubscriptionExistInAzure ([string]$subscriptionname)
{

    if (($Global:AzureRmManagementGroup.Children |? { $_.Type -eq '/subscriptions' -and $_.DisplayName -eq $subscriptionname}).count -eq 1)
    {
        return $true
    }
    return $false
}

function IsSubscriptionInRightManagementGroup ([string]$subscriptionname, [string]$currentmanagementgroup)
{
    if ( ($Global:AzureRmManagementGroup.Children |? { $_.Type -eq '/subscriptions' -and  $_.DisplayName -eq $subscriptionname}).count -eq 1  )
    {
        $managementgroupinAzure = $Global:AzureRmManagementGroup |? { $_.children.Type -eq '/subscriptions' -and  $_.children.DisplayName -eq $subscriptionname}
        
        if($currentmanagementgroup -eq $managementgroupinAzure.DisplayName )
        {
            return $true
        }
    }
    return $false    
}


function New-IAC4DCASubsriptionProvisioning(    $subscriptionName = "Hub for North Europe", 
                                                $SubscriptionDisplayName = "Hub for North Europe",
                                                $ManagementGroupName = "Hub",
                                                $offerType = "MS-AZR-0017P"                                                                                              
                                            )
{
        $subscription = Get-AzureRmSubscription -SubscriptionName "$subscriptionName" -ErrorAction SilentlyContinue

        if($subscription -eq $null)
        {
                        
            Write-Host "Creating new subscription"

            $subscription = New-AzureRmSubscription -Name $subscriptionName -OfferType $offerType `
                                                    -EnrollmentAccountObjectId (Get-AzureRmEnrollmentAccount)[0].ObjectId

            Write-Host "Creating new subscription Success!"


            # Assign Subscription to its Management Group .
            # $subscription =Get-AzureRmSubscriptionDefinition -Name $subscriptionName1
            New-AzureRmManagementGroupSubscription -GroupName $ManagementGroupName -SubscriptionId $subscription.SubscriptionId
        }
        else
        {

             Write-Host "Existing subscription found with ID: $($subscription.Id) Name: $($subscription.Name)"
        }

}

function Ensure-AzureRMManagementAndSubscriptionHierarchy ($AzureIsAuthoritative = $true,

                                                           $TenantRootId = 'b2a0bb8e-3f26-47f8-9040-209289b412a8', 
                                                           $TenantRootname = 'root',
                                                           $MgmtRootFolderPath = "C:\git\FireLake",
                                                           $vstsAAObjectID = (Get-AzureRmADServicePrincipal -SearchString 'iaac4dcm-cd4dcm-bb81881b-d6a7-4590-b14e-bb3c575e42c5').Id,
                                                           $mgmtSubscriptionID= "bb81881b-d6a7-4590-b14e-bb3c575e42c5",        
                                                           [string]$managementgrouptofind = ""
                                                          )
{
    if($AzureIsAuthoritative)
    {  
        #Change Local Folder to reflect heirarchy in Azure
        if(-not $managementgrouptofind )
        {
            $managementgrouptofind = $TenantRootId
        }
        Write-Host "Management Group to Find:  $managementgrouptofind"
    
        TraverseManagementGroupHeirarchy -mgmtgroup (Get-AzureRmManagementGroup -GroupName $managementgrouptofind -Expand -Recurse) 

        #Delete is not implmeneted
    }
    else {
        #Push Local Folder Structure to Azure
        $global:AzureRmManagementGroup = (Get-AzureRmManagementGroup) |% { Get-AzureRmManagementGroup -GroupName $_.Name -Expand } 

    
        #Parent will alawys exist due to how recurse works
        Get-ChildItem -Recurse -Path $MgmtRootFolderPath\$TenantRootname  -Filter "managementgroup.json" |% {

            Write-host "Evaluting : $($_.Directory.FullName)"
            if(IsManagementGroupExistInAzure -managementgroupname $_.Directory.Name)
            {           
                #Write-host "Management Group Exists: $($_.Directory.Name)"
            
                if(IsManagementGroupParentMatchInAzure -managementgroupname $_.Directory.Name -parentmanagemengroupname $_.Directory.Parent.Name)
                {
                    #Write-Host "Parent Matched for  $($_.Directory.Name) to $($_.Directory.Parent.Name)"
                }
                else {
                    #Move Child to Parent in Azure
                    Write-Host "Updating Management Group for  $($_.Directory.Name) to $($_.Directory.Parent.Name)"
                
                    $parentMgmtGroupName = ($_.Directory.Parent.Name)
                    Update-AzureRmManagementGroup -GroupName $($_.Directory.Name) -ParentObject ($Global:AzureRmManagementGroup |? {$_.DisplayName -eq $parentMgmtGroupName})
                }

            }
            else
            {
                #Create Management Group
                Write-host "Creating Management Group: $($_.Directory.Name)"
                $parentMgmtGroupName = ($_.Directory.Parent.Name)

                #reading from the latest (instead of cache) to ensure newly created management group reference came be obtained
                New-AzureRmManagementGroup -GroupName $($_.Directory.Name) -DisplayName $($_.Directory.Name) -ParentId (Get-AzureRmManagementGroup |? {$_.Name -eq $parentMgmtGroupName -or $_.DisplayName -eq $parentMgmtGroupName} ).Id
            }
        } 
    

        #Checking for Subscription
        Get-ChildItem -Recurse -Path $MgmtRootFolderPath\$TenantRootname  -Filter "subscription.json" |% {
        
            Write-host "Evaluting : $($_.Directory.FullName)"
            if(IsSubscriptionExistInAzure -subscriptionname  $_.Directory.Name)
            { 
                #Write-Host "Subscription exists : $($_.Directory.Name)"

                if(-not (IsSubscriptionInRightManagementGroup -subscriptionname ($_.Directory.Name) -currentmanagementgroup ($_.Directory.Parent.Name)))
                {
                    #moving subscription to 
                    Write-Host "Moving Subscription $($_.Directory.Name) to $($_.Directory.Parent.Name)"
                
                    #Querying Azure as cache might no be updated
                    $parentMgmtGroup =  Get-AzureRmManagementGroup -GroupName ($_.Directory.Parent.Name)
                    $subscriptionname =  ($_.Directory.Name)
                    $subscriptionID  = ( $Global:AzureRmManagementGroup.children |? { $_.Type -eq '/subscriptions' -and  $_.DisplayName -eq $subscriptionname}).Name
                    New-AzureRmManagementGroupSubscription -GroupName $parentMgmtGroup.Name -SubscriptionId $subscriptionID            
                }
            }
            else {
                #Create new subscription
                Write-Host "Creating New Subscription"
                New-IAC4DCASubsriptionProvisioning -subscriptionname  $_.Directory.Name -SubscriptionDisplayName  $_.Directory.Name -managementgroup $_.Directory.Parent.Name
            }

        }
    
    }
}

function getScope($name)
{
    if(Get-ChildItem -Path $name -Name managementgroup.json)
    {
        $managementgroup = Get-Content -Path $name\managementgroup.json | ConvertFrom-Json
        return $managementgroup.Id    
    }
    elseif(Get-ChildItem -Path $name -Name subscription.json)
    {
        $subscription = Get-Content -Path $name\subscription.json | ConvertFrom-Json
        return "/subscriptions/$($subscription.Id)"
    }
    else
    {
        return "$(getScope -name (Get-Item -Path $name).Parent.FullName)/resourcegroups/$($(Get-Item -Path $name).BaseName)"
    }
}


function IsManagementGroup($name)
{
    if( (getScope ($name)).contains('/providers/Microsoft.Management/'))
    {
        return $true
    }
    return $false
}
function IsSubscription($name)
{
    if( (getScope ($name)).startswith('/subscriptions/') -and (-not (getScope ($name)).contains('/resourcegroups/')))
    {
        return $true
    }
    return $false
}

function IsResourceGroup ($name)
{
    if(IsSubscription -name (get-item -Path $name).Parent.FullName  )
    {
        return $true
    }
    else
    {
        return $false
    }
}


function getAllSubscriptionUnderManagementGroup($name="C:\git\FireLake\root\M2")
{
    #Excluding current path for the time being
    #[array] $effectivepath  = (Get-Item -Path $name\subscription.json)    
    
    $effectivepath = ls $name -Recurse subscription.json -File 
    
    return ($effectivepath )
    #|% { getScope $($_.directory)})
    
}

function Ensure-AzureRMRoleAssignment ($AzureIsAuthoritative = $true, $path = "C:\git\FireLake\root\M2")
{
    [array] $effectivepath  = (Get-Item -Path $path)    
    $effectivepath += (Get-ChildItem -Path $path -Recurse -Directory)

    if($AzureIsAuthoritative)
    {
        $effectivepath |% {
        
            [string]$effectiveScope = getScope (get-item $_.FullName)
            $currentDirectory = $_.FullName
            Write-Host "Effective Scope: $effectiveScope"
            
            $currentAzureRoleAssignments = Get-AzureRmRoleAssignment -Scope $effectiveScope |?  {$_.Scope -eq $effectiveScope}

            $currentAzureRoleAssignments |% {
                $roleassignment = $_                   

                [string] $rolename =  $roleassignment.DisplayName
                [IO.Path]::GetinvalidFileNameChars() |% {$rolename = $rolename.Replace($_," ")}             
                $roleassignmentFileName = Join-path $currentDirectory ("RoleAssignment_" + $roleassignment.RoleDefinitionName + "_" + $rolename + ".json")
                
                
                $roleassignment | ConvertTo-Json -Depth 20 | out-file $roleassignmentFileName
               
            }
            #Implement Deletion Logic  - if local assignment do not exist in Azure, delete file locally       
            Get-ChildItem -file -Path $currentDirectory RoleAssignment*.json |%{                
                
                $localassignment = get-content $_.FullName | ConvertFrom-Json
                $match = ($currentAzureRoleAssignments |? { $_.scope -eq $localassignment.scope -and $_.objectid -eq $localassignment.objectid -and $_.RoleDefinitionId -eq $localassignment.RoleDefinitionId}) 
                if(-not $match)
                {
                    Write-Host "Deleting $($_.FullName)"
                    rm $_.Fullname
                }
            }            
        }
    }
    else
    {
       
        $effectivepath |% {
        
            [string]$effectiveScope = getScope (get-item $_.FullName)
            $currentDirectory = $_.FullName
            Write-Host "Effective Scope: $effectiveScope"

            $currentAzureRoleAssignments = Get-AzureRmRoleAssignment -Scope $effectiveScope |?  {$_.Scope -eq $effectiveScope}

            #Assignment that exists in Azure but not locally, should be deleted
            $currentAzureRoleAssignments |% {
                $roleassignment = $_            
                [string] $rolename =  $roleassignment.DisplayName
                [IO.Path]::GetinvalidFileNameChars() |% {$rolename = $rolename.Replace($_," ")}                          
                
                $roleassignmentFileName = Join-path $currentDirectory ("RoleAssignment_" + $roleassignment.RoleDefinitionName + "_" + $rolename + ".json")                               
                
                if(Test-path $roleassignmentFileName)
                {   
                    #update assignment if file exist
                    $roleassignment | ConvertTo-Json -Depth 20 | out-file $roleassignmentFileName
                } 
                else
                {
                    #delete assignment
                    Remove-AzureRmRoleAssignment -Scope $effectiveScope -RoleDefinitionName $roleassignment.RoleDefinitionName -objectID $roleassignment.objectID                        
                }  
                   
                
            }

            #Push local assignments
            Get-ChildItem -file -Path $currentDirectory RoleAssignment*.json |%{
                
                $localassignment = get-content $_.FullName | ConvertFrom-Json
                $aadobject = $null
                
                $RoleDefinitionName = ($_.BaseName -split '_')[1]
                $displayname = (($_.BaseName -split '_')[2] -split ' ')[0]

                #we have a conflict, fall back on ObjectID on the path
                if((Get-AzureRmADUser -StartsWith $displayname).Id)
                {
                    $aadobject = (Get-AzureRmADUser -StartsWith $displayname)
                    if($aadobject.count -ne 1)
                    {

                        $aadobject = (Get-AzureRmADUser -ObjectId $localassignment.ObjectId)

                    }
                    
                }
                elseif ((Get-AzureRmADServicePrincipal -DisplayNameBeginsWith $displayname).Id)
                {
                    $aadobject = (Get-AzureRmADServicePrincipal -DisplayNameBeginsWith $displayname)
                    if($aadobject.count -ne 1)
                    {

                        $aadobject = (Get-AzureRmADServicePrincipal -ObjectId $localassignment.ObjectId)

                    }
                }

                
                

                if($aadobject -ne $null)
                {
                 
                    $azureassignment = Get-AzureRmRoleAssignment -Scope $effectiveScope -RoleDefinitionName $RoleDefinitionName -ObjectId $aadobject.Id 
                    if(-not $azureassignment)
                    {
                        New-AzureRmRoleAssignment -Scope $effectiveScope -RoleDefinitionName $RoleDefinitionName -objectID $aadobject.Id
                    }
                    else
                    {
                        Write-Host "Assignment Already Exists for: $($_.FullName )"
                    }
                }
            }
            
           
        }

    }
}


function Ensure-AzureRMPolicyDefinition ($AzureIsAuthoritative = $true, $path = "C:\git\FireLake\root\M2")
{
    [array] $effectivepath  = (Get-Item -Path $path)    
    $effectivepath += (Get-ChildItem -Path $path -Recurse -Directory)

    if($AzureIsAuthoritative)
    {
        $effectivepath |% {
        
            [string]$effectiveScope = getScope (get-item $_.FullName)
            $currentDirectory = $_.FullName
            Write-Host "Effective Scope: $effectiveScope"
            
            if(IsManagementGroup (get-item $_.FullName))
            {
                $currentPolicyDefinitionsInAzure = Get-AzureRmPolicyDefinition -Custom -ManagementGroupName $_.Basename |? {$_.Properties.policyType -ne 'Builtin'}  
            }
            else
            {
                $currentPolicyDefinitionsInAzure = Get-AzureRmPolicyDefinition -Custom -SubscriptionId ($effectiveScope -split '/' | select -last 1) |? {$_.Properties.policyType -ne 'Builtin'} 
            }

            foreach ($policydefinition in $currentPolicyDefinitionsInAzure) 
            {
                
                $policydefinitionFileName = Join-path $currentDirectory ("PolicyDefinition_" + $policydefinition.Name + ".json")
                $policydefinition | ConvertTo-Json -Depth 100 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } |out-file -FilePath $policydefinitionFileName
               
            }
            #Implement Deletion Logic  - if local assignment do not exist in Azure, delete file locally       
            foreach ($policyfile in  (Get-ChildItem -file -Path $currentDirectory PolicyDefinition*.json)) 
            {                
                
                $localassignment = get-content $policyfile.FullName | ConvertFrom-Json
                $match = ($currentPolicyDefinitionsInAzure |? { $_.Name -eq $localassignment.Name}) 
                if(-not $match)
                {
                    Write-Host "Deleting $($policyfile.FullName)"
                    rm ($policyfile.FullName)
                }
            }            
        }
    }
    else
    {
       
        $effectivepath |% {
        
            [string]$effectiveScope = getScope (get-item $_.FullName)
            $currentDirectory = $_.FullName
            Write-Host "Effective Scope: $effectiveScope"

            if(IsManagementGroup ($_.FullName))
            {
                $currentPolicyDefinitionsInAzure = Get-AzureRmPolicyDefinition -Custom -ManagementGroupName $_.Basename |? {$_.Properties.policyType -ne 'Builtin'}  
            }
            else
            {
                $currentPolicyDefinitionsInAzure = Get-AzureRmPolicyDefinition -Custom -SubscriptionId ($effectiveScope -split '/' | select -last 1) |? {$_.Properties.policyType -ne 'Builtin'} 
            }

            #Assignment that exists in Azure but not locally, should be deleted
            foreach ($policydefinition in $currentPolicyDefinitionsInAzure) 
            {                          
                $policydefinitionFileName = Join-path $currentDirectory ("PolicyDefinition_" + $policydefinition.Name + ".json")
                if(Test-path $policydefinitionFileName)
                {   
                    #update assignment if file exist
                    $policydefinition | ConvertTo-Json -Depth 100 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } |out-file -FilePath $policydefinitionFileName
                } 
                else
                {
                    #delete assignment
                    Write-Host "Removing Remove-AzureRmPolicyDefinition -Id $($policydefinition.ResourceId)"
                    Remove-AzureRmPolicyDefinition -Id $policydefinition.ResourceId -force
                                        
                }  
                   
                
            }

            #Push local assignments
            Get-ChildItem -file -Path $currentDirectory PolicyDefinition*.json |%{
                
                $localassignment = get-content $_.FullName | ConvertFrom-Json
                
                [string]$policyname = ($_.basename).replace("PolicyDefinition_", "")
                $localassignment.Name = $policyname
                [string]$policyJsonRule = "$($localassignment.Properties.policyRule | ConvertTo-Json -Depth 100 |  % { [System.Text.RegularExpressions.Regex]::Unescape($_) })"
                [string]$policyJsonParameters = "$($localassignment.Properties.parameters | ConvertTo-Json -Depth 100 |  % { [System.Text.RegularExpressions.Regex]::Unescape($_) })"

                               
                if(IsManagementGroup ($_.DirectoryName))
                {
                    Write-Host "New-AzureRmPolicyDefinition  -ManagementGroupName ($_.Directory.Name) -Name $policyname"
                    $result = New-AzureRmPolicyDefinition -Mode All -ManagementGroupName ($_.Directory.Name) -Name $policyname -Policy $policyJsonRule -Parameter $policyJsonParameters
                }
                else 
                {
                    Write-Host "New-AzureRmPolicyDefinition $($_.fullname)"
                    $result = New-AzureRmPolicyDefinition -Mode All  -SubscriptionId ($effectiveScope -split '/' | select -last 1) -Name $policyname -Policy $policyJsonRule -Parameter $policyJsonParameters
                }

                if($result -ne $null)
                {
                    $result | ConvertTo-Json -Depth 100 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } |out-file -FilePath $_.FullName
                }
                

            }
            
           
        }

    }
}

function Ensure-AzureRMPolicySetDefinition ($AzureIsAuthoritative = $true, $path = "C:\git\FireLake\root\M2")
{
    [array] $effectivepath  = (Get-Item -Path $path)    
    $effectivepath += (Get-ChildItem -Path $path -Recurse -Directory)

    if($AzureIsAuthoritative)
    {
        $effectivepath |% {
        
            [string]$effectiveScope = getScope (get-item $_.FullName)
            $currentDirectory = $_.FullName
            Write-Host "Effective Scope: $effectiveScope"


            
            if(IsManagementGroup (get-item $_.FullName))
            {
                $currentPolicySetDefinitionsInAzure = Get-AzureRmPolicySetDefinition -Custom -ManagementGroupName $_.Basename |? {$_.Properties.policyType -ne 'Builtin'}  
            }
            else
            {
                $currentPolicySetDefinitionsInAzure = Get-AzureRmPolicySetDefinition -Custom -SubscriptionId ($effectiveScope -split '/' | select -last 1) |? {$_.Properties.policyType -ne 'Builtin'} 
            }

            foreach ($policydefinition in $currentPolicySetDefinitionsInAzure) 
            {
                
                $policydefinitionFileName = Join-path $currentDirectory ("PolicySetDefinition_" + $policydefinition.Name + ".json")
                $policydefinition | ConvertTo-Json -Depth 100 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } |out-file -FilePath $policydefinitionFileName
               
            }
            #Implement Deletion Logic  - if local assignment do not exist in Azure, delete file locally       
            foreach ($policyfile in  (Get-ChildItem -file -Path $currentDirectory PolicySetDefinition*.json)) 
            {                
                
                $localassignment = get-content $policyfile.FullName | ConvertFrom-Json
                $match = ($currentPolicySetDefinitionsInAzure |? { $_.Name -eq $localassignment.Name}) 
                if(-not $match)
                {
                    Write-Host "Deleting $($policyfile.FullName)"
                    rm ($policyfile.FullName)
                }
            }            
        }
    }
    else
    {
       
        $effectivepath |% {
        
            [string]$effectiveScope = getScope (get-item $_.FullName)
            $currentDirectory = $_.FullName
            Write-Host "Effective Scope: $effectiveScope"

            if(IsManagementGroup ($_.FullName))
            {
                $currentPolicyDefinitionsInAzure = Get-AzureRmPolicySetDefinition -Custom -ManagementGroupName $_.Basename |? {$_.Properties.policyType -ne 'Builtin'}  
            }
            else
            {
                $currentPolicyDefinitionsInAzure = Get-AzureRmPolicySetDefinition -Custom -SubscriptionId ($effectiveScope -split '/' | select -last 1) |? {$_.Properties.policyType -ne 'Builtin'} 
            }

            #Assignment that exists in Azure but not locally, should be deleted
            foreach ($policydefinition in $currentPolicyDefinitionsInAzure) 
            {                          
                $policydefinitionFileName = Join-path $currentDirectory ("PolicySetDefinition_" + $policydefinition.Name + ".json")
                if(Test-path $policydefinitionFileName)
                {   
                    #update assignment if file exist
                    $policydefinition | ConvertTo-Json -Depth 100 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } |out-file -FilePath $policydefinitionFileName
                } 
                else
                {
                    #delete assignment
                    Remove-AzureRmPolicySetDefinition -Id $policydefinition.ResourceId -force
                                        
                }  
                   
                
            }

            #Push local assignments
            Get-ChildItem -file -Path $currentDirectory PolicySetDefinition*.json |%{
                
                $localassignment = get-content $_.FullName | ConvertFrom-Json
                
                [string]$policyname = ($_.basename).replace("PolicySetDefinition_", "")
                $localassignment.Name = $policyname
                [string]$policyJsonRule = "$($localassignment.Properties.policyDefinitions | ConvertTo-Json -Depth 100 |  % { [System.Text.RegularExpressions.Regex]::Unescape($_) })"
                [string]$policyJsonParameters = "$($localassignment.Properties.parameters | ConvertTo-Json -Depth 100 |  % { [System.Text.RegularExpressions.Regex]::Unescape($_) })"

                               
                if(IsManagementGroup ($_.DirectoryName))
                {
                    $result = New-AzureRmPolicySetDefinition -ManagementGroupName ($_.Directory.Name) -Name $policyname -Policy $policyJsonRule -Parameter $policyJsonParameters
                }
                else
                {
                    $result = New-AzureRmPolicySetDefinition -SubscriptionId ($effectiveScope -split '/' | select -last 1) -Name $policyname -Policy $policyJsonRule -Parameter $policyJsonParameters
                }

                if($result -ne $null)
                {
                    $result | ConvertTo-Json -Depth 100 | % { [System.Text.RegularExpressions.Regex]::Unescape($_) } |out-file -FilePath $_.FullName
                }

            }
           
        }

    }
}


function Ensure-AzureRMPolicyAssignment ($AzureIsAuthoritative = $true, $path = "C:\git\FireLake\root\M2")
{
    [array] $effectivepath  = (Get-Item -Path $path)    
    $effectivepath += (Get-ChildItem -Path $path -Recurse -Directory)

    if($AzureIsAuthoritative)
    {
        $effectivepath |% {
        
            [string]$effectiveScope = getScope (get-item $_.FullName)
            $currentDirectory = $_.FullName
            Write-Host "Effective Scope: $effectiveScope"
            
            $currentPolicyAssignmentsInAzure = Get-AzureRmPolicyAssignment -Scope $effectiveScope |? {$_.policyassignmentid.contains($effectiveScope)}

            foreach ($policyassignment in $currentPolicyAssignmentsInAzure) 
            {
                
                $policyAssignmentFileName = Join-path $currentDirectory ("PolicyAssignment_" + $policyassignment.Name + ".json")
                $policyassignment | ConvertTo-Json -Depth 100 | out-file -FilePath $policyAssignmentFileName
               
            }

            #Implement Deletion Logic  - if local assignment do not exist in Azure, delete file locally       
            foreach ($policyassignment in  (Get-ChildItem -file -Path $currentDirectory PolicyAssignment*.json)) 
            {                
                
                $localassignment = get-content $policyassignment.FullName | ConvertFrom-Json
                $match = ($currentPolicyAssignmentsInAzure |? { $_.Name -eq $localassignment.Name}) 
                if(-not $match)
                {
                    Write-Host "Deleting $($policyassignment.FullName)"
                    rm ($policyassignment.FullName)
                }
            }            
        }
    }
    else
    {
        $effectivepath |% {
        
            [string]$effectiveScope = getScope (get-item $_.FullName)
            $currentDirectory = $_.FullName
            Write-Host "Effective Scope: $effectiveScope"
            
            $currentPolicyAssignmentsInAzure = Get-AzureRmPolicyAssignment -Scope $effectiveScope |? {$_.policyassignmentid.contains($effectiveScope)}

            foreach ($policyassignment in $currentPolicyAssignmentsInAzure) 
            {
                
                $policyAssignmentFileName = Join-path $currentDirectory ("PolicyAssignment_" + $policyassignment.Name + ".json")


                if(Test-path $policyAssignmentFileName)
                {   
                    #update assignment if file exist
                    $policyassignment | ConvertTo-Json -Depth 100 | out-file -FilePath $policyAssignmentFileName
                } 
                else
                {
                    #delete 
                    Write-Host "Remove-AzureRmPolicyAssignment -Name $($policyassignment.Name)"
                    Remove-AzureRmPolicyAssignment -Scope $effectiveScope -Name $policyassignment.Name
                    
                }
               
            }
                 

            #Push local assignments
            Get-ChildItem -file -Path $currentDirectory PolicyAssignment*.json |%{
                
                $localassignment = get-content $_.FullName | ConvertFrom-Json
                $policyassignmentname = $_.BaseName.replace("PolicyAssignment_",'')
                $policydefinition = Get-AzureRmPolicyDefinition -Id $localassignment.Properties.policyDefinitionId 
                $policyassignmentparameters = "$($localassignment.Properties.parameters | ConvertTo-Json -Depth 100 |  % { [System.Text.RegularExpressions.Regex]::Unescape($_) })"

                $Policy = Get-AzureRmPolicyDefinition -BuiltIn | Where-Object {$_.Properties.DisplayName -eq 'Allowed locations'}

                $match = ($currentPolicyAssignmentsInAzure |? { $_.name -eq $policyassignmentname }) 
                if(-not $match)
                {
                    Write-Host "New-AzureRmPolicyAssignment $($_.FullName)"
                    New-AzureRmPolicyAssignment -Scope $effectiveScope `
                                            -Location 'northeurope' `
                                            -AssignIdentity `
                                            -Name $policyassignmentname `
                                            -DisplayName $policyassignmentname `
                                            -PolicyDefinition $policydefinition `
                                            -PolicyParameter $policyassignmentparameters    
                }
                else
                {
                    Write-Host "Policy Assignment already exists for $($_.FullName)"
                }

            }            
           
        }

    }
}


function Ensure-AzureRMRoleDefinition ($AzureIsAuthoritative = $true, $path = "C:\git\FireLake\root\M2", $managementsubscriptionID=$mgmtSubscriptionID)
{
    #This must run under the context of managemnt subscription otherwise roledefinition will be spewed

    Select-AzureRmSubscription -SubscriptionObject (Get-AzureRmSubscription -SubscriptionId $managementsubscriptionID)

    
    [array] $effectivepath  = (Get-Item -Path $path)    
    $effectivepath += (Get-ChildItem -Path $path -Recurse -Directory)

    if($AzureIsAuthoritative)
    {

        foreach ($currentDirectory in getAllSubscriptionUnderManagementGroup -name $path )
        {
        
            if ( (getscope ($currentDirectory.DirectoryName)).contains($managementsubscriptionID) )
            {
        
                $currentAzureRoleDefinition = Get-AzureRmRoleDefinition -Custom -Scope "/subscriptions/$managementsubscriptionID"

                foreach($roledefinitioninAzure in $currentAzureRoleDefinition)
                {
                          
                    $roledefinitioninAzureFileName = Join-path $currentDirectory.DirectoryName ("RoleDefinition_" + $roledefinitioninAzure.Name + ".json")
                    $roledefinitioninAzure | ConvertTo-Json -Depth 20 | out-file $roledefinitioninAzureFileName
               
                }
                #Implement Deletion Logic  - if local assignment do not exist in Azure, delete file locally       
                Get-ChildItem -file -Path $currentDirectory.DirectoryName RoleDefinition*.json |%{                
                
                    $localassignment = get-content $_.FullName | ConvertFrom-Json
                    $match = ($currentAzureRoleDefinition |? { $_.name -eq $localassignment.name}) 
                    if(-not $match)
                    {
                        Write-Host "Deleting $($_.FullName)"
                        rm $_.Fullname
                    }
                }
            }
        }            
        
    }
    else
    {

        foreach ($currentDirectory in getAllSubscriptionUnderManagementGroup -name $path )
        {
        
            #Only targeting Management Subscription
            if ( (getscope ($currentDirectory.DirectoryName)).contains($managementsubscriptionID) )
            {
        
                $currentAzureRoleDefinition = Get-AzureRmRoleDefinition -Custom -Scope "/subscriptions/$managementsubscriptionID"
                foreach($roledefinitioninAzure in $currentAzureRoleDefinition)
                {
                          
                    $roledefinitioninAzureFileName = Join-path $currentDirectory.DirectoryName ("RoleDefinition_" + $roledefinitioninAzure.Name + ".json")
                    
                    if(Test-Path $roledefinitioninAzureFileName)
                    {
                        $roledefinitioninAzure | ConvertTo-Json -Depth 20 | out-file $roledefinitioninAzureFileName
                    }
                    else
                    {
                        Remove-AzureRmRoleDefinition -Scope "/subscriptions/$managementsubscriptionID" -Name $roledefinitioninAzure.Name -Force -Confirm:$false
                    }
               
                }
                 #Push local assignments
                Get-ChildItem -file -Path $currentDirectory.DirectoryName RoleDefinition*.json |%{
                    
                     $localassignment = get-content $_.FullName | ConvertFrom-Json                   
                     $rolename = $_.BaseName.replace("RoleDefinition_",'')

                    $localassignment.Name = $rolename
                    $localassignment.Description = $rolename
                    $localassignment.AssignableScopes = getAllSubscriptionUnderManagementGroup -name $path |% {getscope $_.Directoryname}


                     $match = ($currentAzureRoleDefinition |? { $_.name -eq $localassignment.name}) 
                     if(-not $match)
                     {
                    
                        $return = New-AzureRmRoleDefinition -Role $localassignment
                
                     }
                     else
                     {
                        $return = Set-AzureRmRoleDefinition -Role $localassignment
                     }
                    #Saving update role definition with possibly new ID
                    $return | ConvertTo-Json -Depth 20 | out-file $_.FullName
                
                }
                    
            }
        }
     
    }
}


function Ensure-AzureRMRGDeployment ($AzureIsAuthoritative = $true, $path = "C:\git\FireLake\root\M2")
{
    [array] $effectivepath  = (Get-Item -Path $path)    
    $effectivepath += (Get-ChildItem -Path $path -Recurse -Directory)

    if($AzureIsAuthoritative)
    {
        $effectivepath |% {
        
            [string]$effectiveScope = getScope (get-item $_.FullName)
            $currentDirectory = $_.FullName
            
            if(IsSubscription -name $_.fullname)
            {
                Write-Host "Effective Scope: $effectiveScope"
                $subscription = Select-AzureRmSubscription -SubscriptionObject (Get-AzureRmSubscription -SubscriptionName (get-item $currentDirectory).Name)
                $currentRGinAzure = Get-AzureRmResourceGroup
                
                foreach ($rginAzure in $currentRGinAzure)
                {
                    $rgfilename = Join-path ("$((get-item $currentDirectory).FullName)\$($rginAzure.location)_$($rginAzure.Resourcegroupname)")  ("resourcegroup.json")
                    
                    mkdir -Confirm:$false -Force -Path ("$((get-item $currentDirectory).FullName)\$($rginAzure.location)_$($rginAzure.Resourcegroupname)") | out-null

                    $rginAzure | ConvertTo-Json -Depth 20 | out-file $rgfilename -Force
                                    
                }
            }
        }
    }
    else
    {
        $effectivepath |% {
        
            [string]$effectiveScope = getScope (get-item $_.FullName)
            $currentDirectory = $_.FullName
            
            if(IsResourceGroup -name $_.fullname)
            {
                Write-Host "Effective Scope: $effectiveScope"
                $subscription = Select-AzureRmSubscription -SubscriptionObject (Get-AzureRmSubscription -SubscriptionName (get-item $currentDirectory).Parent)
                $currentRGinAzure = Get-AzureRmResourceGroup
                
                $rgfilename = Join-path $currentDirectory ("resourcegroup.json")

                

                

                foreach ($rginAzure in $currentRGinAzure)
                {
                    
                    
                    if(Test-Path (join-path ((get-item $currentDirectory).Parent.FullName)  "$($rginAzure.location)_$($rginAzure.Resourcegroupname)"))
                    {
                        $currentRGinAzure | ConvertTo-Json -Depth 20 | out-file $rgfilename
                    }
                    else
                    {
                        Write-host "Deleting Resource Group: $effectiveScope"
                        
                        #Disabling deleting until subscription level deployment authoritative model is figuerd out.
                        #Remove-AzureRmResourceGroup -Id $rginAzure.ResourceId -Force -AsJob
                    }
                }
                

                #Push local 

                Get-ChildItem -Recurse -file -Path $currentDirectory Deployment*.json -Exclude *.parameters.json|%{
                    
                    $location = ($_.Directory.Name -split "_")[0]                        
                    $rgname = ($_.DirectoryName -split "_")[1]
                    if(-not( $currentRGinAzure |? { $_.Resourcegroupname -eq $rgname}))
                    {
                        New-AzureRmResourceGroup -Name $rgname -Location $location -Force
                    }

                    $deploymentname = $(get-date -Format "yy-MM-dd-HH-mm-ss") + "-" + ($_.BaseName).replace("Deployment_",'')
                    
                    $deploymentparameterfilename = ""

                    if(Test-Path -Path "$($_.FullName.Replace($_.Extension,'')).parameters.json.private")
                    {
                        $deploymentparameterfilename = "$($_.FullName.Replace($_.Extension,'')).parameters.json.private"
                        
                    }
                    elseif(Test-Path -Path "$($_.FullName.Replace($_.Extension,'')).parameters.json")
                    {
                        (Test-Path -Path "$($_.FullName.Replace($_.Extension,'')).parameters.json")   
                    }
               
                    if($deploymentparameterfilename -ne "")
                    {
                        New-AzureRmResourceGroupDeployment -Name $deploymentname `
                                                           -Mode Incremental `
                                                           -ResourceGroupName $rgname `
                                                           -TemplateFile $_.FullName `
                                                           -TemplateParameterFile $deploymentparameterfilename `
                                                           -AsJob

                    }
                    else
                    {
                         New-AzureRmResourceGroupDeployment -Name $deploymentname `
                                                           -Mode Incremental `
                                                           -ResourceGroupName $rgname `
                                                           -TemplateFile $_.FullName -AsJob
                    }
                    
                   
                
                } 
            }
            elseif(IsSubscription  -name $_.fullname)
            {
                Write-Host "Effective Scope: $effectiveScope"
                $subscription = Select-AzureRmSubscription -SubscriptionObject (Get-AzureRmSubscription -SubscriptionName (get-item $currentDirectory).Name)
                $currentRGinAzure = Get-AzureRmResourceGroup
                
                $rgfilename = Join-path $currentDirectory ("resourcegroup.json")

                #no recurse othewise, it will includ RG level deployment
                Get-ChildItem -file -Path $currentDirectory Deployment*.json |? {$_.FullName -notlike "*.parameters.json"}|%   {
    
                    $location = ($_.Name -split "_")[1]                        
                    
                    $deploymentname = $(get-date -Format "yy-MM-dd-HH-mm-ss") + "-" + ($_.BaseName).replace("Deployment_",'')
                    
                    $deploymentparameterfilename = ""

                    if(Test-Path -Path "$($_.FullName.Replace($_.Extension,'')).parameters.json.private")
                    {
                        $deploymentparameterfilename = "$($_.FullName.Replace($_.Extension,'')).parameters.json.private"
                        
                    }
                    elseif(Test-Path -Path "$($_.FullName.Replace($_.Extension,'')).parameters.json")
                    {
                        (Test-Path -Path "$($_.FullName.Replace($_.Extension,'')).parameters.json")   
                    }
               
                    if($deploymentparameterfilename -ne "")
                    {
                       
                        New-AzureRmDeployment -Name  $deploymentname -Location $location `
                                                    -TemplateFile $_.FullName `
                                                    -TemplateParameterFile $deploymentparameterfilename `
                                                    -AsJob                        

                    }
                    else
                    {
                         New-AzureRmDeployment -Name  $deploymentname -Location $location `
                                                    -TemplateFile $_.FullName `                                                    
                                                    -AsJob     
                    }
                    
                   
                
                } 

            }
        }

    }
}


#Ensure-AzureRMManagementAndSubscriptionHierarchy -AzureIsAuthoritative:$true
#Ensure-AzureRMRoleDefinition -AzureIsAuthoritative:$true
#Ensure-AzureRMRoleAssignment -AzureIsAuthoritative:$true
#Ensure-AzureRMPolicySetDefinition -AzureIsAuthoritative:$true
#Ensure-AzureRMPolicyDefinition -AzureIsAuthoritative:$true
#Ensure-AzureRMPolicyAssignment -AzureIsAuthoritative:$true
#Ensure-AzureRMRGDeployment -AzureIsAuthoritative:$true


#Ensure-AzureRMManagementAndSubscriptionHierarchy -AzureIsAuthoritative:$false
#Ensure-AzureRMRoleDefinition -AzureIsAuthoritative:$false
#Ensure-AzureRMRoleAssignment -AzureIsAuthoritative:$false
#Ensure-AzureRMPolicySetDefinition -AzureIsAuthoritative:$false
#Ensure-AzureRMPolicyDefinition -AzureIsAuthoritative:$false
#Ensure-AzureRMPolicyAssignment -AzureIsAuthoritative:$false




#Ensure-AzureRMRoleAssignment -AzureIsAuthoritative:$true -path:C:\git\FireLake\root\M2\Managed-Production\SharedService\m2-ne-prod-hub1
#Ensure-AzureRMRoleAssignment -AzureIsAuthoritative:$true 


