<#
    Author: Brian P. Mohr
    Email: brian@cybermohr.com
    Social: https://www.linkedin.com/in/bpmohr
    Script Name: Get-VMDataCollectionRules.ps1
    Version: 1.0
    Description:
        This PowerShell script is designed to audit Azure Virtual Machines for associated Data
        Collection Rules. The script will loop through all the subscriptions within an Azure tenant to
        identify Virtual Machines and check if they have a Data Collection Rule associated with them
        for log collection. If a rule is associated, it also fetches the destination where the collected
        data is being sent.
#>

# Login to Azure
# Uncomment the below line if you're not already logged in
# Login-AzAccount

# Initialize an array to hold the results
$results = @()

# Fetch and loop through all subscriptions
$subscriptions = Get-AzSubscription
foreach ($subscription in $subscriptions) {
    # Select the subscription for subsequent commands
    Set-AzContext -Subscription $subscription.Id

    Write-Host "Checking VMs in subscription: $($subscription.Name)"

    # Fetch the list of all VMs in the subscription
    $vms = Get-AzVM

    # Loop through each VM to check if it has an associated Data Collection Rule
    foreach ($vm in $vms) {
        # Initialize a custom PSObject to hold VM and rule info
        $vmInfo = [PSCustomObject]@{
            SubscriptionName = $subscription.Name
            VMName = $vm.Name
            ResourceGroupName = $vm.ResourceGroupName
            DataCollectionRuleAssociated = $false
            DataStream = $null
            DataDestination = $null
        }

        # Fetch the list of data collection rules associated with the VM's resource group
        $dataCollectionRules = Get-AzDataCollectionRuleAssociation -TargetResourceId $vm.Id

        # Check if VM has an associated data collection rule
        foreach ($rule in $dataCollectionRules) {
            if ($rule.Id -match $vm.Name) {
                $vmInfo.DataCollectionRuleAssociated = $rule.Name
                
                # Fetch raw JSON data of the Data Collection Rule
                $ruleJson = Get-AzDataCollectionRule -RuleId $rule.DataCollectionRuleId | ConvertTo-Json -Depth 10

                # Extract the destination information manually (the exact path might differ based on your setup)
                $ruleObj = $ruleJson | ConvertFrom-Json
                $vmInfo.DataStream =  $ruleObj.DataFlows.Streams | ConvertTo-Json
                $vmInfo.DataDestination = $ruleObj.DataFlows.Destinations | ConvertTo-Json
                
                break
            }
        }

        # Add the custom PSObject to the results array
        $results += $vmInfo
    }
}

# Export the results to a CSV file
$results | Export-Csv -Path "VM_DataCollectionRule_Status.csv" -NoTypeInformation

Write-Host "Script completed. The results are saved in VM_DataCollectionRule_Status.csv"
