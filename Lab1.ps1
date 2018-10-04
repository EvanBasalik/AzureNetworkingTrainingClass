$nsgName="Lab-nsg"
$resourceGroupName="rgAzureNetworkingLab"
$location="westus"

#check if we need to log in
$context =  Get-AzureRmContext
if ($context.Environment -eq $null) {
    Login-AzureRmAccount
}

Write-Host "Creating resource group..." -ForegroundColor Yellow
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

#add NSG rule to allow port 80 inbound from anywhere
Write-Host "Creating NSG..." -ForegroundColor Yellow
New-AzureRmNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName -Location $location

Write-Host "Allowing HTTP..." -ForegroundColor Yellow
$nsg=Get-AzureRmNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName | `
    Add-AzureRmNetworkSecurityRuleConfig -Name "Allow_Port_80" -Access `
    Allow -Protocol Tcp -Direction Inbound -Priority 110 -SourceAddressPrefix * `
    -SourcePortRange * -DestinationAddressPrefix VirtualNetwork -DestinationPortRange 80 |`
    Set-AzureRmNetworkSecurityGroup 

Write-Host "Allowing RDP..." -ForegroundColor Yellow
$nsg=Get-AzureRmNetworkSecurityGroup -Name $nsgName -ResourceGroupName $resourceGroupName | `
    Add-AzureRmNetworkSecurityRuleConfig -Name "Allow_RDP" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 120 `
    -SourceAddressPrefix Internet -SourcePortRange * `
    -DestinationAddressPrefix * -DestinationPortRange 3389 | `
    Set-AzureRmNetworkSecurityGroup 


#VNETs
Write-Host "Creating VNETs..." -ForegroundColor Yellow
for ($i = 0; $i -lt 2; $i++) {
    $NetworkName = "VNET$($i)"
    $SubnetName = "Subnet1"
    $SubnetAddressPrefix = "10.$($i).0.0/25"
    $VnetAddressPrefix = "10.$($i).0.0/23"
    $SingleSubnet = New-AzureRmVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix

    Write-Host "Creating $($NetworkName)..." -ForegroundColor Yellow
    $Vnet = New-AzureRmVirtualNetwork -Name $NetworkName -ResourceGroupName $ResourceGroupName -Location $Location -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet

    ##add the NSG
    Write-Host "Adding NSG to $($NetworkName)..." -ForegroundColor Yellow
    Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $Vnet -Name $SubnetName -AddressPrefix $SubnetAddressPrefix -NetworkSecurityGroup $nsg
    Set-AzureRmVirtualNetwork -VirtualNetwork $Vnet
}

#credentials for all the VMs
$cred = Get-Credential -Message "Enter information for the local administrator on all VMs"

#create availability set for the load balanced VMs in VNET0
Write-Host "Adding availability set..." -ForegroundColor Yellow
$as = New-AzureRmAvailabilitySet -ResourceGroupName $resourceGroupName -Name "LabAvailabilitySet" -Location $location `
    -Sku aligned `
    -PlatformFaultDomainCount 2 `
    -PlatformUpdateDomainCount 2

##two VMs in VNET0
for ($i = 0; $i -lt 2; $i++) {

    #names, etc.
    $ComputerName = "LabVM$($i)"
    Write-Host "Creating $($ComputerName)..." -ForegroundColor Yellow

    $VMName = "LabVM$($i)"
    $VMSize = "Standard_B2ms"
    $NICName = "LabVM$($i)-NIC"
    $PublicIPAddressName = "LabVM$($i)-PIP"

    $Vnet = Get-AzureRmVirtualNetwork -Name  "VNET0" -ResourceGroupName $resourceGroupName
    $PIP = New-AzureRmPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $resourceGroupName -Location $location -DomainNameLabel "$($resourceGroupName)PIP$($i)".ToLower() -AllocationMethod Static
    $NIC = New-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $resourceGroupName -Location $location -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id

    # Create a virtual machine configuration
    $vmConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetId $as.Id | `
    Set-AzureRmVMOperatingSystem -Windows -ComputerName $VMName -Credential $cred | `
    Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer `
    -Skus 2016-Datacenter -Version latest | Add-AzureRmVMNetworkInterface -Id $NIC.Id

    #create the VM
    New-AzureRmVM -ResourceGroupName $resourceGroupName -Location $location -vm $vmConfig -Verbose
    Write-Host "Created $($ComputerName)..." -ForegroundColor Green
}

##one VM in VNET1
#names, etc.
$ComputerName = "LabVM2"
Write-Host "Creating $($ComputerName)..." -ForegroundColor Yellow

$VMName = $ComputerName
$VMSize = "Standard_B2ms"
$NICName = "$($ComputerName)-NIC"
$PublicIPAddressName = "$($ComputerName)-PIP"

$Vnet = Get-AzureRmVirtualNetwork -Name  "VNET1" -ResourceGroupName $resourceGroupName
$PIP = New-AzureRmPublicIpAddress -Name $PublicIPAddressName -ResourceGroupName $resourceGroupName -Location $location -DomainNameLabel "$($resourceGroupName)PIP2".ToLower() -AllocationMethod Static
$NIC = New-AzureRmNetworkInterface -Name $NICName -ResourceGroupName $resourceGroupName -Location $location -SubnetId $Vnet.Subnets[0].Id -PublicIpAddressId $PIP.Id

# Create a virtual machine configuration
$vmConfig = New-AzureRmVMConfig -VMName $VMName -VMSize $VMSize | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $VMName -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer `
-Skus 2016-Datacenter -Version latest | Add-AzureRmVMNetworkInterface -Id $NIC.Id

#create the VM
New-AzureRmVM -ResourceGroupName $resourceGroupName -Location $location -VM $vmConfig -Verbose
Write-Host "Created $($ComputerName)..." -ForegroundColor Green

#install IIS, configure firewall, create HTML file on all three VMs
Write-Host "Configuring the VMs for Lab..." -ForegroundColor Yellow
for ($i = 0; $i -lt 3; $i++) {
    $VMName = "LabVM$($i)"
    Write-Host "Configuring $($VMName)..." -ForegroundColor Yellow

   ##call the custom script extension to configure the VMs
   Set-AzureRmVMCustomScriptExtension -ResourceGroupName $resourceGroupName `
    -VMName $VMName `
    -Location $location `
    -FileUri https://raw.githubusercontent.com/EvanBasalik/AzureNetworkingTrainingClass/master/ConfigureVMScript.ps1 `
    -Run 'ConfigureVMScript.ps1' `
    -Name "LabPrep"
}

Write-Host "All VMs for Lab created and configured" -ForegroundColor Green

##write out the web server URLs and RDP files
for ($i = 0; $i -lt 3; $i++) {
    $VMName = "LabVM$($i)"

    #Get the public IP
    $vm=Get-AzureRMVM -ResourceGroupName $resourceGroupName -Name $VMName
    $VNIC = Get-AzureRmNetworkInterface | Where-Object {$_.Id -eq $vm.NetworkProfile.NetworkInterfaces[0].Id}
    $EIPPublicIP = Get-AzureRmPublicIpAddress | Where-Object {$_.Id -eq $VNIC.IpConfigurations[0].PublicIpAddress.Id}

    Write-Host "URL for $($VMName) is http://$($EIPPublicIP.IpAddress)/default.html" -ForegroundColor Green

    ##generate the RDP files
    Write-Host "Generating RDP file for $($VMName): " -ForegroundColor Yellow -NoNewline
    Write-Host "$($VMName).rdp" -ForegroundColor Green
    $rdpFile = "$($VMName).rdp"
    "full address:s:$($EIPPublicIP.IpAddress):3389" | Out-File $rdpFile -Force
    "prompt for credentials:i:1" | Out-File $rdpFile -Append
    "administrative session:i:1" | Out-File $rdpFile -Append
}

$OUTPUT= [System.Windows.Forms.MessageBox]::Show("Please go create your ILB and ELB in the portal. Click OK when done." , `
    "Wait for load balancers" , [System.Windows.Forms.MessageBoxButtons]::OK)
#Add an ILB in VNET0 via the portal -> Choose your availability set (LabAvailabilitySet by default), add LB rules, and use TCP 80 for proble
#Add an ELB in VNET0 via the portal -> same as above

$OUTPUT= [System.Windows.Forms.MessageBox]::Show("While you are in the portal, create your shutdown schedules. Click OK when done." , `
    "Wait for shutdown schedule" , [System.Windows.Forms.MessageBoxButtons]::OK)
#Add the shutdown schedule

#Create the Traffic Manager profile
$TMprofile = New-AzureRmTrafficManagerProfile -Name "LabTM" -ResourceGroupName $resourceGroupName `
    -TrafficRoutingMethod Weighted -RelativeDnsName $resourceGroupName -Ttl 5 -MonitorProtocol HTTP -MonitorPort 80 -MonitorPath "/" -MonitorToleratedNumberOfFailures 1 -MonitorTimeoutInSeconds 5 -MonitorIntervalInSeconds 10

#Add the endpoints
for ($i = 0; $i -lt 3; $i++) {
    $PIPName = "LabVM$($i)-PIP"
    $ip = Get-AzureRmPublicIpAddress -Name $PIPName -ResourceGroupName $resourceGroupName
    New-AzureRmTrafficManagerEndpoint -Name "$($PIPName)-TMEndpoint" -ProfileName $TMprofile.Name `
        -ResourceGroupName $resourceGroupName -Type AzureEndpoints -TargetResourceId $ip.Id -EndpointStatus Enabled 
}
