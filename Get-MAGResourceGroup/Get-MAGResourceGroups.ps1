[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("Summary","Detailed")]
    $Collection
)
<# 
Write-Host "Please run this script region by region manually in the ISE!"
#Move to the location of the script if you not threre already.
$ScriptDir = [System.IO.Path]::GetDirectoryName($myInvocation.MyCommand.Definition) 
Set-Location $ScriptDir

#if not logged in to Azure, start login
if ((Get-AzureRmContext).Account -eq $Null) {
Connect-AzureRmAccount -Environment AzureUSGovernment}

break
#>

#region Build Config File
#$Collection = "Summary"
$subs = Get-AzureRmSubscription | Select-Object Name,Id | Out-GridView -OutputMode Multiple -Title "Select Subscriptions"

foreach ($sub in $subs) {
    Write-Verbose ("Azure Subscription: {0}" -f $sub.Name)
    Select-AzureRmSubscription -SubscriptionName $sub.Name | Out-Null

    $SubRGs = Get-AzureRmResourceGroup | Select-Object ResourceGroupName,Location,@{L="Subscription";E={$sub.Name}},@{L="SubscriptionId";E={$sub.Id}} | Out-GridView -OutputMode Multiple -Title "Select Resource Groups"
    
    $Global:RGHash = [HashTable]::Synchronized(@{})
    Foreach ($RG in $SubRGs) {
        #VM Data Collection
        $RGHash.$($rg.ResourceGroupName) = [Ordered]@{}
        Write-Host "Please wait to while Virtual Machine data is gathered..." -ForegroundColor Cyan
        $VMs = Get-AzureRmVM -ResourceGroupName $RG.ResourceGroupName
        $i = 0
        Foreach ($VM in $VMs) {
            Write-Progress -Activity "Collecting Virtual Machine Data" -Status ("Working on VM {0} of {1}" -f $i,$VMs.Count) -CurrentOperation ("Resource Group: {0} | Virtual Machine: {1}" -f $RG.ResourceGroupName,$VM.Name) -PercentComplete (($i/$VMs.Count)*100)
            If ($Collection -eq "Summary") {
                $VM = Get-AzureRmVM -Name $VM.Name -ResourceGroupName $VM.ResourceGroupName -DisplayHint Expand
                $RGHash.$($rg.ResourceGroupName).$($VM.Name) = @{}
                $RGHash.$($rg.ResourceGroupName).$($VM.Name).Extensions = $VM.Extensions
            }
            Else {$RGHash.$($rg.ResourceGroupName).$($VM.Name) = @{}}

            $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo = @{}
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.VmId = $VM.VmId
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.Name = $VM.Name
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.Tags = $VM.Tags
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.OSType = $VM.StorageProfile.OsDisk.OsType
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.Location = $VM.Location
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.LicenseType = $VM.LicenseType
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.VMSize = $VM.HardwareProfile.VmSize
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.DiskCount = ""
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.NicCount = ""
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.NicCapacity = $VM.NetworkProfile.NetworkInterfaces.Capacity

            #Region AVSet DataCollection
            If ([System.String]::IsNullOrEmpty($VM.AvailabilitySetReference.Id)) {$AvailabilitySet = "Not Assigned"}
            Else {
                Switch ($Collection) {
                    "Detailed" {
                        $AvailabilitySet = $VM.AvailabilitySetReference.Id.Substring($VM.AvailabilitySetReference.Id.LastIndexOf("/")+1)
                        $AVInfo = Get-AzureRmVm -ResourceGroupName $RG.ResourceGroupName -Name $VM.Name -Status | Select-Object PlatformFaultDomain,PlatformUpdateDomain
                        $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.AvailabilitySet = $AvailabilitySet
                        $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.FaultDomain = $AVInfo.PlatformFaultDomain
                        $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.UpdateDomain = $AVInfo.PlatformUpdateDomain
                    }
                    "Summary" {
                        $AvailabilitySet = $VM.AvailabilitySetReference.Id.Substring($VM.AvailabilitySetReference.Id.LastIndexOf("/")+1)
                        $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.AvailabilitySet = $AvailabilitySet
                        $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.FaultDomain = "Unknown"
                        $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.UpdateDomain = "Unknown"
                    }
                }
            }
            #EndRegion

            #Region Disk Data Collection
            [System.Collections.ArrayList]$VMDiskInfo = @()
            If ($VM.StorageProfile.DataDisks) {
                #Capture OS Disk Info
                $objDisk = [PSCustomObject][Ordered]@{
                    Name = $VM.StorageProfile.OsDisk.Name
                    Caching = $VM.StorageProfile.OsDisk.Caching
                    DiskSizeGB = $Disk.DiskSizeGB
                }
                [Void]$VMDiskInfo.Add($objDisk)
                
                #Capture Data Disk Info
                Foreach ($Disk in $VM.StorageProfile.DataDisks) {
                    $objDisk = [PSCustomObject][Ordered]@{
                        Name = $Disk.Name
                        Caching = $Disk.Caching
                        DiskSizeGB = $Disk.DiskSizeGB
                    }
                    [Void]$VMDiskInfo.Add($objDisk)
                }
            }
            Else {
                $objDisk = [PSCustomObject][Ordered]@{
                    Name = $VM.StorageProfile.OsDisk.Name
                    Caching = $VM.StorageProfile.OsDisk.Caching
                    DiskSizeGB = $Disk.DiskSizeGB
                }
                [Void]$VMDiskInfo.Add($objDisk)
            }
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).Disks = $VMDiskInfo
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.DiskCount = $VMDiskInfo.Count
            #EndRegion

            #Region Network Data Collection
            Switch ($Collection) {
                "Detailed" {
                    [System.Collections.ArrayList]$VMNetworkInfo = @()
                    If ($VM.NetworkProfile.NetworkInterfaces.Count -gt 1) {
                        Foreach ($VMNetwork in $VM.NetworkProfile.NetworkInterfaces) {
                            $VMInterface = (Get-AzureRmNetworkInterface -ResourceGroupName $RG.ResourceGroupName).Where{$_.Id -eq $VMNetwork.id}
                            $objVMInterface = [PSCustomObject][Ordered]@{
                                Name = $VMInterface.name
                                MacAddress = $VMInterface.MacAddress
                                Primary = $VMInterface.Primary
                                IpVersion = $VMInterface.IpConfigurations.PrivateIpAddressVersion
                                IpAddress = $VMInterface.IpConfigurations.PrivateIpAddress
                                IpAllocationMethod = $VMInterface.IpConfigurations.PrivateIpAllocationMethod
                                EnableAcceleratedNetworking = $VMInterface.EnableAcceleratedNetworking
                                EnableIPForwarding = $VMInterface.EnableIPForwarding
                            }
                            [Void]$VMNetworkInfo.Add($objVMInterface)
                        }
                    }
                    Else {
                        $VMInterface = (Get-AzureRmNetworkInterface -ResourceGroupName $RG.ResourceGroupName).Where{$_.Id -eq $VM.NetworkProfile.NetworkInterfaces.Id}
                        $objVMInterface = [PSCustomObject][Ordered]@{
                            Name = $VMInterface.name
                            MacAddress = $VMInterface.MacAddress
                            Primary = $VMInterface.Primary
                            IpVersion = $VMInterface.IpConfigurations.PrivateIpAddressVersion
                            IpAddress = $VMInterface.IpConfigurations.PrivateIpAddress
                            IpAllocationMethod = $VMInterface.IpConfigurations.PrivateIpAllocationMethod
                            EnableAcceleratedNetworking = $VMInterface.EnableAcceleratedNetworking
                            EnableIPForwarding = $VMInterface.EnableIPForwarding
                        }
                        [Void]$VMNetworkInfo.Add($objVMInterface)
                    }
                }
                "Summary" {
                    $VMNetworkInfo = $VM.NetworkProfile.NetworkInterfaces
                }
            }
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).Networks = $VMNetworkInfo
            $RGHash.$($rg.ResourceGroupName).$($VM.Name).VmInfo.NicCount = $VMNetworkInfo.Count
            #EndRegion
            $i++
        }        
    }
}


