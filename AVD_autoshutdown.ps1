#Set-AzContext -SubscriptionId "c3c7bba1-b60e-4b14-aa3b-2cb0b3dc81f3"
az account set -s "c3c7bba1-b60e-4b14-aa3b-2cb0b3dc81f3"
# Set the resource group name and shutdown time
$ResourceGroupName = "rg-avd-km2"
$ShutdownTime = "02:30"

# Set the auto-shutdown and auto-start properties
$AutoShutdown = $true
$AutoStart = $false

# Loop through all VMs in the resource group and set the auto-shutdown property
# $VMs = az vm list -g $ResourceGroupName --query "[].id" -o tsv
$VMs = Get-AzVM -ResourceGroupName "rg-avd-km2"

foreach ($VM_ID in $VMs) {
    $ID = $VM_ID.Name
    $RG = $VM_ID.ResourceGroupName
    az vm auto-shutdown -g $RG --name $ID --time $ShutdownTime
    # Uncomment the next line to restart the VMs if needed
    # az vm restart --ids $VM_ID --no-wait
}