

# Ensure the Az module is installed and connect to Azure
if (-not (Get-Module -ListAvailable -Name Az)) {
    Install-Module -Name Az -Force -AllowClobber
}

if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Import sorted resources from CSV if needed
$sortedResources = Import-Csv -Path "AzureResources.csv"

# Create empty arrays to store resource role assignments and errors
$resourceRoleAssignments = @()
$errorList = @()

# Loop through each resource in the sortedResources array
foreach ($resource in $sortedResources) {
    # Extract resource details
    $subscriptionId = $resource.Subscription
    $resourceGroup = $resource.ResourceGroup
    $resourceType = $resource.ResourceType
    $resourceName = $resource.ResourceName

    # Set the current context to the correct subscription
    Set-AzContext -SubscriptionId $subscriptionId

    try {
        # Get the role assignments for the specific resource
        $roleAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/$resourceType/$resourceName"

        foreach ($roleAssignment in $roleAssignments) {
            # Try to resolve the principal name (user, group, or service principal)
            $principalName = $null
            switch ($roleAssignment.ObjectType) {
                "User" {
                    $principal = Get-AzADUser -ObjectId $roleAssignment.SignInName -ErrorAction SilentlyContinue
                    if ($principal) {
                        $principalName = $principal.UserPrincipalName
                    }
                }
                "Group" {
                    $principal = Get-AzADGroup -ObjectId $roleAssignment.SignInName -ErrorAction SilentlyContinue
                    if ($principal) {
                        $principalName = $principal.DisplayName
                    }
                }
                "ServicePrincipal" {
                    $principal = Get-AzADServicePrincipal -ObjectId $roleAssignment.SignInName -ErrorAction SilentlyContinue
                    if ($principal) {
                        $principalName = $principal.DisplayName
                    }
                }
            }

            # Add the role assignment details to the array
            $resourceRoleAssignments += [pscustomobject]@{
                Subscription   = $subscriptionId
                ResourceGroup  = $resourceGroup
                ResourceType   = $resourceType
                ResourceName   = $resourceName
                PrincipalName  = $principalName
                RoleDefinition = $roleAssignment.RoleDefinitionName
                PrincipalType  = $roleAssignment.PrincipalType
                Scope          = $roleAssignment.Scope
                AssignedBy     = $roleAssignment.CreatedBy
            }
        }
    }
    catch {
        # Handle any errors with querying role assignments gracefully
        Write-Warning "Failed to get role assignments for resource: $resourceName in $resourceGroup ($subscriptionId). Error: $_"
        $errorList += [pscustomobject]@{
            Subscription  = $subscriptionId
            ResourceGroup = $resourceGroup
            ResourceType  = $resourceType
            ResourceName  = $resourceName
            ErrorMessage  = $_.Exception.Message
        }
    }
}

# Output the result to the console in a table format
$resourceRoleAssignments | Format-Table -AutoSize

# Optionally, export to CSV for further analysis
$resourceRoleAssignments | Export-Csv -Path "ResourceRoleAssignments.csv" -NoTypeInformation

# Export the errors to a CSV file
if ($errorList.Count -gt 0) {
    $errorList | Export-Csv -Path "ResourceErrors.csv" -NoTypeInformation
    Write-Host "Errors encountered during the process have been saved to ResourceErrors.csv"
}
else {
    Write-Host "No errors encountered during the process."
}