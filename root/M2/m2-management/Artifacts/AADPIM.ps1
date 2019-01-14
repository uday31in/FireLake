#Loads Active Directory Authentication Library
function Load-ActiveDirectoryAuthenticationLibrary(){
    $moduleDirPath = [Environment]::GetFolderPath("MyDocuments") + "\WindowsPowerShell\Modules"
    $modulePath = $moduleDirPath + "\AADGraph"

    if(-not (Test-Path ($modulePath+"\Nugets"))) {New-Item -Path ($modulePath+"\Nugets") -ItemType "Directory" | out-null}
    $adalPackageDirectories = (Get-ChildItem -Path ($modulePath+"\Nugets") -Filter "Microsoft.IdentityModel.Clients.ActiveDirectory*" -Directory)

    if($adalPackageDirectories.Length -eq 0){
        Write-Host "Active Directory Authentication Library Nuget doesn't exist. Downloading now ..." -ForegroundColor Yellow
        if(-not(Test-Path ($modulePath + "\Nugets\nuget.exe")))
        {
            Write-Host "nuget.exe not found. Downloading from http://www.nuget.org/nuget.exe ..." -ForegroundColor Yellow
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile("http://www.nuget.org/nuget.exe",$modulePath + "\Nugets\nuget.exe");
        }
        $nugetDownloadExpression = $modulePath + "\Nugets\nuget.exe install Microsoft.IdentityModel.Clients.ActiveDirectory -Version 2.14.201151115 -OutputDirectory " + $modulePath + "\Nugets | out-null"
        Invoke-Expression $nugetDownloadExpression
    }

    $adalPackageDirectories = (Get-ChildItem -Path ($modulePath+"\Nugets") -Filter "Microsoft.IdentityModel.Clients.ActiveDirectory*" -Directory)
    $ADAL_Assembly = (Get-ChildItem "Microsoft.IdentityModel.Clients.ActiveDirectory.dll" -Path $adalPackageDirectories[$adalPackageDirectories.length-1].FullName -Recurse)
    $ADAL_WindowsForms_Assembly = (Get-ChildItem "Microsoft.IdentityModel.Clients.ActiveDirectory.WindowsForms.dll" -Path $adalPackageDirectories[$adalPackageDirectories.length-1].FullName -Recurse)
    if($ADAL_Assembly.Length -gt 0 -and $ADAL_WindowsForms_Assembly.Length -gt 0){
        Write-Host "Loading ADAL Assemblies ..." -ForegroundColor Green
        [System.Reflection.Assembly]::LoadFrom($ADAL_Assembly[0].FullName) | out-null
        [System.Reflection.Assembly]::LoadFrom($ADAL_WindowsForms_Assembly.FullName) | out-null
        return $true
    }
    else{
        Write-Host "Fixing Active Directory Authentication Library package directories ..." -ForegroundColor Yellow
        $adalPackageDirectories | Remove-Item -Recurse -Force | Out-Null
        Write-Host "Not able to load ADAL assembly. Delete the Nugets folder under" $modulePath ", restart PowerShell session and try again ..."
        return $false
    }
}
 
#Acquire AAD token
function AcquireToken($mfa){
    $clientID = "8f141bfd-4249-4bc3-86f2-f72ab7b75e0a"
    $redirectUri = "https://pimmsgraph"
 
    $authority = "https://login.microsoftonline.com/common"
    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority,$false
    if($mfa)
    {
        $authResult = $authContext.AcquireToken("https://graph.microsoft.com",$ClientID,$redirectUri,[Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Auto, [Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier]::AnyUser, "amr_values=mfa")
        Set-Variable -Name mfaDone -Value $true -Scope Global
    }
    else
    {
        $authResult = $authContext.AcquireToken("https://graph.microsoft.com",$ClientID,$redirectUri,[Microsoft.IdentityModel.Clients.ActiveDirectory.PromptBehavior]::Always)
    }
    if($authResult -ne $null)
    {
        Write-Host "User logged in successfully ..." -ForegroundColor Green
    }
    Set-Variable -Name headerParams -Value @{'Authorization'="$($authResult.AccessTokenType) $($authResult.AccessToken)"} -Scope Global
    Set-Variable -Name assigneeId -Value $authResult.UserInfo.UniqueId -Scope Global
}
 
#Gets my jit assignments
function MyJitAssignments(){
    $urlme = $global:MSGraphRoot + "me/"
    $response = Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $urlme -Method Get
    $me = ConvertFrom-Json $response.Content
    $subjectId = $me.id
    Write-Host $subjectId

    $url = $serviceRoot + "roleAssignments?`$expand=linkedEligibleRoleAssignment,subject,roleDefinition(`$expand=resource)&`$filter=(assignmentState+eq+'Eligible')+and+(subjectId+eq+'" + $subjectId + "')" 

    Write-Host $url
    $response = Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url -Method Get
    $assignments = ConvertFrom-Json $response.Content
    Write-Host ""
    Write-Host "Role assignments..." -ForegroundColor Green
    $i = 0
    $obj = @()
    foreach ($assignment in $assignments.value)
    {
        $item = New-Object psobject -Property @{
        Id = ++$i
        RoleAssignmentId =  $assignment.id
        ResourceId =  $assignment.roleDefinition.resource.id
        OriginalId =  $assignment.roleDefinition.resource.externalId
        ResourceName =  $assignment.roleDefinition.resource.displayName
        ResourceType =  $assignment.roleDefinition.resource.type
        RoleId = $assignment.roleDefinition.id
        RoleName = $assignment.roleDefinition.displayName
        ExpirationDate = $assignment.endDateTime
        SubjectId = $assignment.subject.id
    }
    $obj = $obj + $item
    }
 
    return $obj
}
 

#List resources
function ListResources(){
    $url = $serviceRoot + "resources?`$filter=(type+eq+'subscription')" 
     Write-Host $url

    $response = Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url -Method Get
    $resources = ConvertFrom-Json $response.Content
    $i = 0
    $obj = @()
    foreach ($resource in $resources.value)
    {
        $item = New-Object psobject -Property @{
        Id = ++$i
        ResourceId =  $resource.id
        ResourceName =  $resource.DisplayName
        Type =  $resource.type
        ExternalId =  $resource.externalId
    }
    $obj = $obj + $item
}
 
return $obj
}

#List roles
function ListRoles($resourceId){
    $url = $serviceRoot + "resources/" + $resourceId + "/roleDefinitions?&`$orderby=displayName"
    Write-Host $url

    $response = Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url -Method Get
    $roles = ConvertFrom-Json $response.Content
    $i = 0
    $obj = @()
    foreach ($role in $roles.value)
    {
        $item = New-Object psobject -Property @{
        Id = ++$i
        RoleDefinitionId =  $role.id
        RoleName =  $role.DisplayName
    }
    $obj = $obj + $item
    }
 
    return $obj
}

#List Assignment
function ListAssignmentsWithFilter($resourceId, $roleDefinitionId){
    $url = $serviceRoot + "resources/" + $resourceId + "`/roleAssignments?`$expand=subject,roleDefinition(`$expand=resource)&`$filter=(roleDefinition/id+eq+'" + $roleDefinitionId + "')"
    Write-Host $url

    $response = Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url -Method Get
    $roleAssignments = ConvertFrom-Json $response.Content
    $i = 0
    $obj = @()
    foreach ($roleAssignment in $roleAssignments.value)
        {
        $item = New-Object psobject -Property @{
        Id = ++$i
        RoleAssignmentId =  $roleAssignment.id
        ResourceId =  $roleAssignment.roleDefinition.resource.id
        OriginalId =  $roleAssignment.roleDefinition.resource.externalId
        ResourceName =  $roleAssignment.roleDefinition.resource.displayName
        ResourceType =  $roleAssignment.roleDefinition.resource.type
        RoleId = $roleAssignment.roleDefinition.id
        RoleName = $roleAssignment.roleDefinition.displayName
        ExpirationDate = $roleAssignment.endDateTime
        SubjectId = $roleAssignment.subject.id
        UserName = $roleAssignment.subject.displayName
        AssignmentState = $roleAssignment.AssignmentState
    }
    $obj = $obj + $item
}
 
return $obj
}

#List Users
function ListUsers($user_search){
    $url = $MSGraphRoot + "users?`$filter=startswith(displayName,'" + $user_search + "')"
    Write-Host $url

    $response = Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url -Method Get
    $users = ConvertFrom-Json $response.Content
    $i = 0
    $obj = @()
    foreach ($user in $users.value)
    {
        $item = New-Object psobject -Property @{
        Id = ++$i
        UserId =  $user.id
        UserName =  $user.DisplayName
    }
    $obj = $obj + $item
    }

    return $obj
}

#Activates the user
function Activate($isRecursive = $false){
    if($isRecursive -eq $false)
    {
        $assignments = MyJitAssignments
        $assignments | Format-Table -AutoSize -Wrap Id,RoleName,ResourceName,ResourceType,ExpirationDate
        $choice = Read-Host "Enter Id to activate"
        [int]$hours = Read-Host "Enter Activation duration in hours"
        $reason = Read-Host "Enter Reason"
    }
 
    $id = $assignments[$choice-1].RoleAssignmentId
    $resourceId = $assignments[$choice-1].ResourceId
    $roleDefinitionId = $assignments[$choice-1].RoleId
    $subjectId = $assignments[$choice-1].SubjectId
    $url = $serviceRoot + "roleAssignmentRequests"
    $postParams = '{"id":"00000000-0000-0000-0000-000000000000","assignmentState":"Active","type":"UserAdd","reason":"' + $reason + '","roleDefinitionId":"' + $roleDefinitionId + '","resourceId":"' + $resourceId + '","subjectId":"' + $subjectId + '","schedule":{"duration":"PT' + $hours + 'H","startDateTime":"' + (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ") + '","type":"Once"},"linkedEligibleRoleAssignmentId":"' + $id + '"}'
    write-Host $postParams

    try
    {
        $response = Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url -Method Post -ContentType "application/json" -Body $postParams
        Write-Host "Activation request queued successfully ..." -ForegroundColor Green
    }
    catch
    {
        $stream = $_.Exception.Response.GetResponseStream()
        $stream.Position = 0;
        $streamReader = New-Object System.IO.StreamReader($stream)
        $err = $streamReader.ReadToEnd()
        $streamReader.Close()
        $stream.Close()
 
        if($mfaDone -eq $false -and $err.Contains("MfaRule"))
        {
            Write-Host "Prompting the user for mfa ..." -ForegroundColor Green
            AcquireToken true
            Activate $true
        }
        else
        {
            Write-Host $err -ForegroundColor Red
        }
    }
}
 
#Deactivates the user
function Deactivate($isRecursive = $false){
    if($isRecursive -eq $false)
    {
        $assignments = MyJitAssignments
        $assignments | Format-Table -AutoSize -Wrap id,RoleName,ResourceName,ResourceType,ExpirationDate
        $choice = Read-Host "Enter Id to deactivate"
    }
 
    $id = $assignments[$choice-1].RoleAssignmentId
    $resourceId = $assignments[$choice-1].ResourceId
    $roleDefinitionId = $assignments[$choice-1].RoleId
    $subjectId = $assignments[$choice-1].SubjectId
    $url = $serviceRoot + "roleAssignmentRequests"
    $postParams = '{"assignmentState":"Active","type":"UserRemove","roleDefinitionId":"' + $roleDefinitionId + '","resourceId":"' + $resourceId + '","subjectId":"' + $subjectId + '"}'
    $response = Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url -Method Post -ContentType "application/json" -Body $postParams
    Write-Host "Role deactivated successfully ..." -ForegroundColor Green
}
 
#List RoleAssignment
function ListAssignment(){
    #List and Pick resource
    $resources = ListResources
    $resources | Format-Table -AutoSize -Wrap Id, ResourceName, Type, ExternalId
    $res_choice = Read-Host "Pick an resource Id for assigment"
    $resourceId = $resources[$res_choice-1].ResourceId

    #List and Pick a role
    $roles = ListRoles($resourceId)
    $roles | Format-Table -AutoSize -Wrap Id, RoleName, RoleDefinitionId
    $role_choice = Read-Host "Pick a role Id"
    $roleDefinitionId = $roles[$role_choice-1].RoleDefinitionId
    write-Host $roleDefinitionId

    #List Member
    $roleAssignments = ListAssignmentsWithFilter $resourceId $roleDefinitionId
    $roleAssignments | Format-Table -AutoSize -Wrap Id, ResourceName, ResourceType, RoleName, UserName, AssignmentState, ExpirationDate
}

#Assign a user to Eligible
function AssignmentEligible() {
    #List and Pick resource
    $resources = ListResources
    $resources | Format-Table -AutoSize -Wrap Id, ResourceName, Type, ExternalId
    $res_choice = Read-Host "Pick an resource Id for assigment"
    $resourceId = $resources[$res_choice-1].ResourceId

    #List and Pick a role
    $roles = ListRoles($resourceId)
    $roles | Format-Table -AutoSize -Wrap Id, RoleName, RoleDefinitionId
    $role_choice = Read-Host "Pick a role Id"
    $roleDefinitionId = $roles[$role_choice-1].RoleDefinitionId
    write-Host $roleDefinitionId

    #Search user by Name, and pick a user
    $user_search = Read-Host "user Name start with..."
    $users = ListUsers($user_search)
    $users | Format-Table -AutoSize -Wrap Id, UserName, UserId
    $user_choice = Read-Host "Pick a user Id"
    $subjectId = $users[$user_choice-1].UserId


    $url = $serviceRoot + "roleAssignmentRequests"
    # Update end time
    $ts = New-TimeSpan -Days 30
    $postParams = '{"assignmentState":"Eligible","type":"AdminAdd","reason":"Assign","roleDefinitionId":"' + $roleDefinitionId + '","resourceId":"' + $resourceId + '","subjectId":"' + $subjectId + '","schedule":{"startDateTime":"' + (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ") + '","endDateTime":"' + ((get-date) + $ts).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ") + '","type":"Once"}}'
    write-Host $postParams

    try
    {
        $response = Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url -Method Post -ContentType "application/json" -Body $postParams
        Write-Host "Assignment request queued successfully ..." -ForegroundColor Green
    }
    catch
    {
        $stream = $_.Exception.Response.GetResponseStream()
        $stream.Position = 0;
        $streamReader = New-Object System.IO.StreamReader($stream)
        $err = $streamReader.ReadToEnd()
        $streamReader.Close()
        $stream.Close()
 
        if($mfaDone -eq $false -and $err.Contains("MfaRule"))
        {
            Write-Host "Prompting the user for mfa ..." -ForegroundColor Green
            AcquireToken true
            Activate $true
        }
        else
        {
            Write-Host $err -ForegroundColor Red
        }
    }
}

#Show menu
function ShowMenu(){
    Write-Host ""
    Write-Host "Azure RBAC JIT - PowerShell Menu v1.0"
    Write-Host "  1. List your eligible role assignments"
    Write-Host "  2. Activate an eligible role"
    Write-Host "  3. Deactivate an active role"
    Write-Host "  4. List Assignment against a resource"
    Write-Host "  5. Assign a user to a role"
    Write-Host "  6. Exit"
}
 
############################################################################################################################################################################
 
$global:serviceRoot = "https://graph.microsoft.com/beta/privilegedAccess/azureResources/"
$global:MSGraphRoot = "https://graph.microsoft.com/v1.0/"
$global:headerParams = ""
$global:assigneeId = ""
$global:mfaDone = $false;
 
Load-ActiveDirectoryAuthenticationLibrary
AcquireToken
 
do
{
    ShowMenu
    #Write-Host "Enter your selection"
    $input = Read-Host "Enter your selection"
    switch ($input)
    {
        '1'
        {
            $assignments = MyJitAssignments
            $assignments | Format-Table -AutoSize -Wrap id,RoleName,ResourceName,ResourceType,ExpirationDate
        }
        '2'
        {
            Activate
        }
        '3'
        {
            Deactivate
        }
        '4'
        {
            ListAssignment
        }
        '5'
        {
            AssignmentEligible
        }
        '6'
        {
            return
        }
    }
}
until ($input -eq '6')
 
Write-Host ""