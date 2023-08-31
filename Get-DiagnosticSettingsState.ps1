<#
    Author: Brian P. Mohr
    Email: brian@cybermohr.com
    Social: https://www.linkedin.com/in/bpmohr
    Script Name: Get-DiagnosticSettingsState.ps1
    Version: 1.0
    Description:
        This PowerShell script checks the diagnostic settings of all Azure resources
        across all subscriptions in a tenant. It exports a CSV file that includes 
        details about the diagnostic settings for each resource.
#>

# Load the Az module
Import-Module Az

# Authenticate to Azure (uncomment and run if not authenticated)
# Connect-AzAccount

# Create an array to hold the results
$results = @()

# Get all subscriptions in the tenant
$subscriptions = Get-AzSubscription

# Loop through each subscription
foreach ($subscription in $subscriptions) {
    # Select the subscription
    Select-AzSubscription -SubscriptionId $subscription.Id
    Write-Host "Checking Resources in subscription: $($subscription.Name)"

    # Get all resource IDs in the subscription
    $resourceIds = Get-AzResource | Select-Object -ExpandProperty ResourceId

    # Loop through each resource ID and check diagnostic settings
    foreach ($originalResourceId in $resourceIds) {
        $resourcesToCheck = @($originalResourceId)

        # Check if the resource ID contains a storage account
        if ($originalResourceId -match "storageAccounts") {
            $services = @("blobServices/default", "queueServices/default", "tableServices/default", "fileServices/default")
            foreach ($service in $services) {
                $resourcesToCheck += "$originalResourceId/$service"
            }
        }

        foreach ($resourceId in $resourcesToCheck) {
            # Get the diagnostic settings for the resource
            $diagnosticSettings = Get-AzDiagnosticSetting -ResourceId $resourceId -ErrorAction SilentlyContinue

            # If the resource has diagnostic settings
            if ($diagnosticSettings) {
                # Check each diagnostic setting
                foreach ($diagnosticSetting in $diagnosticSettings) {

                    # Create result object
                    $results += New-Object PSObject -property @{
                        "ResourceID" = $resourceId
                        "SubscriptionName" = $subscription.Name
                        "DiagnosticEnabled" = "true"
                    }
                }
            } else {
                # Create result object for resources without diagnostic settings
                $results += New-Object PSObject -property @{
                    "ResourceID" = $resourceId
                    "SubscriptionName" = $subscription.Name
                    "DiagnosticEnabled" = "false"
                }
            }
        }
    }
}

# Export results to CSV
$results | Export-Csv -Path "TenantDiagnosticSettings.csv" -NoTypeInformation

Write-Host "Script completed. The results are saved in TenantDiagnosticSettings.csv"
