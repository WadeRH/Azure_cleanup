


# Ensure you have the Az module
if (-not (Get-Module -ListAvailable -Name Az)) {
    Install-Module -Name Az -Force -AllowClobber
}

# Connect to Azure Account (if not already connected)
if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# Define the subscriptions you want to query
$subscriptions = @(
    # "c6db1048-7bba-4e0c-90f6-92cf190ae9cf", # Azure Subsription 1
    "c3c7bba1-b60e-4b14-aa3b-2cb0b3dc81f3", # Main - Pay-As-You-Go
    # "d758e8ed-5e1d-42a4-b05f-de5711a1aa6f", # Pay-As-You-Go (visual studio subscription)
    "55d24ba2-8e52-4205-9de5-9acd58ce7a84", # Phoenix DevTest
    "a2f59314-f9a8-444f-8b6e-59525dda90f5"   # PhoenixProduction
)

# Create an empty array to store all resources
$allResources = @()

# Loop through each subscription
foreach ($subscriptionId in $subscriptions) {
    # Set the context to the current subscription
    Set-AzContext -SubscriptionId $subscriptionId

    # Get all resource groups in the subscription
    $resourceGroups = Get-AzResourceGroup

    foreach ($rg in $resourceGroups) {
        # Get all resources in the resource group
        $resources = Get-AzResource -ResourceGroupName $rg.ResourceGroupName

        foreach ($resource in $resources) {
            # Add the resource to the array
            $allResources += [pscustomobject]@{
                Subscription  = $subscriptionId
                ResourceGroup = $rg.ResourceGroupName
                ResourceType  = $resource.ResourceType
                ResourceName  = $resource.Name
                Location      = $resource.Location
            }
        }
    }
}

# Sort resources by Subscription, Resource Group, then Resource Type
$sortedResources = $allResources | Sort-Object Subscription, ResourceGroup, ResourceType

# Output the result to the console
$sortedResources | Format-Table -AutoSize

# Optionally, export to CSV for further analysis
$sortedResources | Export-Csv -Path "AzureResources.csv" -NoTypeInformation
