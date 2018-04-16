# AzureNetworkingTrainingClass

**Overview**

In this walkthrough, you will start with a single VM running a small IIS web site. You will then layer in an internal load balancer and an external load balancer. Next, you will make the site geographically redundant and ensure low latency for end users by layering in Traffic Manager.

After that, you will learn about VNET peering by making the web site accessible from another VNET without going over the internet.

Lastly, you will use Azure VPN point-to-site functionality to make the site accessible from your local machine across a secure VPN tunnel to your VNET (*in the script, but not yet in the walkthrough*).

When you are done, you will be able to run the script TestLB.ps1 and point it either to the external load balancer IP or the Traffic Manager endpoint and see the server servicing the requests rotate as expected.

You can follow the steps below using the portal or you can leverage the PowerShell scripts (*CLI scripts coming*)

**Details**
1. Create a resource group with a custom name
1. Create an NSG named lab-nsg
   1. HTTP Rule: inbound TCP, * for source/destination address prefixes, * for source port, target of port 80
   1. RDP Rule: inbound TCP, * for source/destination address prefixes, * for source port, target of port 3389
1. Create VNET0
   1. VNET range 10.1.0.0/23
   1. Single Subnet named Subnet1 with range 10.1.0.0/25
   1. Apply the lab-nsg to the VNET
1. Create VNET1
   1. VNET range 10.1.0.0/23
   1. Single Subnet named Subnet1 with range 10.1.0.0/25
   1. Apply the lab-nsg to the VNET
1. Create an availability set with 2 fault domains and 2 update domains
1. Create two Windows VMs in VNET0 (VM0 and VM1)
   1. Any size
   1. Have a public IP for RDP access
   1. In the availability set you created earlier
1. Create a third Windows VM in VNET1
   1. Any size
   1. Have a public IP for RDP access
1. Remote into VM0
   1. Add a firewall rule allow inbound TCP port 80
   1. Add IIS
     1. Manually or via PowerShell (Add-WindowsFeature Web-Server)
   1. Create HTML file for demo purposes
     1. In PowerShell run: $env:COMPUTERNAME | Out-File c:\inetpub\wwwroot\default.html -Force
   1. Disable IE enhanced security configuration
     1. In PowerShell run:
     ```PowerShell
         #courtesy of https://sharepointryan.com/2011/06/23/disable-ie-enhanced-security-configuration-esc-using-powershell/
         $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
         $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}
         Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
         Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
         Stop-Process -Name Explorer
     ``` 
   1. Validate everything is working by browsing to http://localhost/default.html
   1. Validate external access by browsing to http://PublicIPofVM/default.html
1. Use the custom script extension to configure VM1 and VM2
   1. For each VM, go to Extensions, Add, and select Custom Script
   1. When prompted for the script file, use the URI: https://raw.githubusercontent.com/EvanBasalik/AzureNetworkingTrainingClass/master/ConfigureVMScript.ps1
   1. Once the script has run, validate everything is working by browsing to http://localhost/default.html on each VM
   1. Validate external access by browsing to http://PublicIPofVM/default.html
1. Add an internal load balancer using VM1 and VM2 on port 80
   1. Choose the availability set you created earlier
1. Add an external load balancer using VM1 and VM2 on port 80
   1. Choose the availability set you created earlier
1. For each VM, go to Auto-Shutdown and enable auto-shutdown
1. Create a new Traffic Manager profile
  1. Routing method: weighted
  1. TTL: 5
  1. Protocol: HTTP
  1. Port: 80
  1. Path: /
1. Add the Azure VMs as endpoints
  1. Type: AzureEndpoints
  1. Resource: Public IP of the Azure VMs
  1. Set each VM to a different weight
 
   
