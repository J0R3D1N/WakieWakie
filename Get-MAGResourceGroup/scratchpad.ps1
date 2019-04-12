<#>
$Subs = Get-AzureRmSubscription
$i = 0
$allvms = [ordered]@{}
Foreach ($sub in $subs) {
    Write-Progress -id 1 -Activity "Virtual Machine Collection Process" -Status ("Subscription {0} of {1}" -f ($i+1),$subs.Count) -CurrentOperation ("Subscription: {0}" -f $sub.Name) -PercentComplete (($i/$subs.count)*100)
    Select-AzureRmSubscription -SubscriptionObject $sub | Out-Null
    $subname = Get-AzureRmContext | % {$_.Name.Split(" ")[0]}
    $allvms.$subname = @{}
    $tmpVMs = Get-AzureRmLocation | % {
        Write-Host ("[{0}] Gathering Virtual Machines from: {1}" -f $subname,$_.Location.ToUpper())
        Get-AzureRmVM -Location $_.location
    }
    $ii = 0
    foreach ($vm in $tmpVMs) {
        Write-Progress -Id 2 -ParentId 1 -Activity "Building VirtualMachine Hashtable" -Status ("Virtual Machine {0} of {1}" -f ($ii+1),$tmpVMs.Count) -CurrentOperation ("Virtual Machine: {0}" -f $vm.Name) -PercentComplete (($ii/$tmpVMs.count)*100)
        $vmsize = $vm.HardwareProfile.vmsize
        If ($allvms.$subname.Keys -contains $vmsize) {
            [Void]$allvms.$subname.$vmsize.Add($vm)
        }
        Else {
            [System.Collections.ArrayList]$allvms.$subname.$vmsize = @()
            [Void]$allvms.$subname.$vmsize.add($vm)
        }
        $ii++
    }
    Write-Progress -id 2 -Activity "Building VirtualMachine Hashtable" -Completed
    $i++
}
Write-Progress -id 1 -Activity "Virtual Machine Collection Process" -Completed


($allvms.'PREPROD-GOV-INTERNAL'["standard_a4_v2"].availabilitysetreference |select id -Unique) | % {
    $avset = $_.id.substring($_.id.lastindexof("/")+1)
    $rgnstring = ($_.id | select-string -Pattern "/resourceGroups/")
    $rgnstartindex = $rgnstring.matches.index + ($rgnstring.matches | % {$_.length})
    $rgnlength = ($_.id | select-string -Pattern "/providers/") | select @{l="value";e={$_.matches.index - $rgnstartindex}}
    $rgn = $_.id.substring($rgnstartindex,$rgnlength.value)
    $avset
    $rgn
    Read-Host
    }
    #>

$RobbyVMs = Import-Csv C:\_Scripts\Repos\PowerShellApps\Update-AzureVMSizes\VM_Resize_List_Robby.csv
$AllVMsToResize = import-csv C:\_Scripts\Repos\PowerShellApps\Update-AzureVMSizes\All_VMs_ToBe_Resized_20190116.csv
$vmhash = $AllVMsToResize | Group-Object Name -AsHashTable -AsString
[System.Collections.ArrayList]$resizelist = @()

foreach ($x in $RobbyVMs) {
    Write-Host "Working on $($x.ServerName)"
    if ($vmhash.Keys -contains $x.servername) {
        $objVM = $vmhash[$x.servername] | select *,@{l="Group";e={$x.Group}}
        [void]$resizelist.Add($objVM)
    }
    Else {
        Write-Warning ("VM: {0} - NOT FOUND" -f $x.ServerName)
    }
}