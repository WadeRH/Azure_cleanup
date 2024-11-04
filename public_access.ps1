# Ensure Az module is installed and connect to Azure
if (-not (Get-Module -ListAvailable -Name Az)) {
    Install-Module -Name Az -Force -AllowClobber
}

if (-not (Get-AzContext)) {
    Connect-AzAccount
}

# If sortedResources isn't available, you can import it from the CSV created in the previous script
# Import sorted resources from CSV if needed
$sortedResources = Import-Csv -Path "AzureResources.csv"

# Array to store results for resources with public access
$publicAccessResources = @()

# Function to check for public access via NSG rules
function Search-NSGAccess {
    param (
        [string]$resourceGroupName,
        [string]$networkInterfaceId
    )
    $publicAccessDetails = @()

    $nsgRules = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -NetworkInterfaceId $networkInterfaceId -ErrorAction SilentlyContinue
    if ($nsgRules) {
        foreach ($nsg in $nsgRules) {
            foreach ($rule in $nsg.SecurityRules) {
                # Check if rule allows inbound traffic from "Any" source (0.0.0.0/0) on any port
                if ($rule.Access -eq "Allow" -and $rule.Direction -eq "Inbound" -and $rule.SourceAddressPrefix -eq "0.0.0.0/0") {
                    $publicAccessDetails += [pscustomobject]@{
                        AccessConfiguration = "NSG Rule"
                        AllowedIPAddresses  = $rule.SourceAddressPrefix
                        RuleName            = $rule.Name
                        PortRange           = $rule.DestinationPortRange
                    }
                }
            }
        }
    }
    return $publicAccessDetails
}

# Function to check for public access via public IP configurations
function Search-PublicIPAccess {
    param (
        [string]$resourceGroupName,
        [string]$resourceName
    )
    $publicAccessDetails = @()

    $publicIP = Get-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name $resourceName -ErrorAction SilentlyContinue
    if ($publicIP) {
        if ($publicIP.IpAddress) {
            $publicAccessDetails += [pscustomobject]@{
                AccessConfiguration = "Public IP"
                AllowedIPAddresses  = $publicIP.IpAddress
                RuleName            = "Direct Public Access"
                PortRange           = "All"
            }
        }
    }
    return $publicAccessDetails
}

# Function to check for public access via firewall rules
function Search-FirewallAccess {
    param (
        [string]$resourceGroupName,
        [string]$resourceName,
        [string]$firewallType
    )
    $publicAccessDetails = @()

    if ($firewallType -eq "SqlServer") {
        # Get firewall rules for SQL Server
        $firewallRules = Get-AzSqlServerFirewallRule -ResourceGroupName $resourceGroupName -ServerName $resourceName -ErrorAction SilentlyContinue
        if ($firewallRules) {
            foreach ($rule in $firewallRules) {
                if ($rule.StartIpAddress -eq "0.0.0.0" -and $rule.EndIpAddress -eq "0.0.0.0") {
                    $publicAccessDetails += [pscustomobject]@{
                        AccessConfiguration = "SQL Server Firewall"
                        AllowedIPAddresses  = "0.0.0.0 (All IPs)"
                        RuleName            = $rule.FirewallRuleName
                        PortRange           = "1433"
                    }
                }
            }
        }
    }
    # Additional firewall types can be checked here (e.g., Cosmos DB, Storage Account)
    return $publicAccessDetails
}

# Function to check for public access via WAF settings
function Search-WAFSettings {
    param (
        [string]$resourceGroupName,
        [string]$resourceName
    )
    $publicAccessDetails = @()

    # Example for Application Gateway WAF configuration (Modify for other WAF types if needed)
    $appGateway = Get-AzApplicationGateway -ResourceGroupName $resourceGroupName -Name $resourceName -ErrorAction SilentlyContinue
    if ($appGateway -and $appGateway.WebApplicationFirewallConfiguration.Enabled) {
        $publicAccessDetails += [pscustomobject]@{
            AccessConfiguration = "WAF Settings"
            AllowedIPAddresses  = "Depends on WAF Rules"
            RuleName            = "WAF Enabled"
            PortRange           = "Depends on WAF Config"
        }
    }
    return $publicAccessDetails
}

# Loop through each resource in the sortedResources array
foreach ($resource in $sortedResources) {
    $subscriptionId = $resource.Subscription
    $resourceGroup = $resource.ResourceGroup
    $resourceType = $resource.ResourceType
    $resourceName = $resource.ResourceName

    # Set the current context to the correct subscription
    Set-AzContext -SubscriptionId $subscriptionId

    $publicAccessDetails = @()

    # Check for public IP access
    # if ($resourceType -eq "Microsoft.Network/publicIPAddresses") {
    #     $publicAccessDetails += Search-PublicIPAccess -resourceGroupName $resourceGroup -resourceName $resourceName
    # }

    # Check for NSG rules allowing public access
    if ($resourceType -eq "Microsoft.Network/networkInterfaces") {
        $publicAccessDetails += Search-NSGAccess -resourceGroupName $resourceGroup -networkInterfaceId $resourceName
    }

    # Check for SQL Server firewall rules allowing public access
    if ($resourceType -eq "Microsoft.Sql/servers") {
        $publicAccessDetails += Search-FirewallAccess -resourceGroupName $resourceGroup -resourceName $resourceName -firewallType "SqlServer"
    }

    # Check for WAF configuration
    if ($resourceType -eq "Microsoft.Network/applicationGateways") {
        $publicAccessDetails += Search-WAFSettings -resourceGroupName $resourceGroup -resourceName $resourceName
    }

    # Additional resource types can be added here with similar logic

    # If any public access details are found, add them to the final array
    if ($publicAccessDetails.Count -gt 0) {
        foreach ($detail in $publicAccessDetails) {
            $publicAccessResources += [pscustomobject]@{
                Subscription  = $subscriptionId
                ResourceGroup = $resourceGroup
                ResourceType  = $resourceType
                ResourceName  = $resourceName
                AccessType    = $detail.AccessConfiguration
                AllowedIPs    = $detail.AllowedIPAddresses
                RuleOrConfig  = $detail.RuleName
                PortRange     = $detail.PortRange
            }
        }
    }
}

# Output the public access results to a CSV file
if ($publicAccessResources.Count -gt 0) {
    $publicAccessResources | Export-Csv -Path "PublicAccessResources.csv" -NoTypeInformation
    Write-Host "Resources with public access have been saved to PublicAccessResources.csv"
}
else {
    Write-Host "No resources with public access were found."
}
