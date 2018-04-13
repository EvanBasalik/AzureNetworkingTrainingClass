# AzureNetworkingTrainingClass

**Overview**

In this walkthrough, you will start with a single VM running a small IIS web site. You will then layer in an internal load balancer and an external load balancer. Next, you will make the site geographically redundant and ensure low latency for end users by layering in Traffic Manager.

After that, you will learn about VNET peering by making the web site accessible from another VNET without going over the internet.

Lastly, you will use Azure VPN point-to-site functionality to make the site accessible from your local machine across a secure VPN tunnel to your VNET.

You can follow the steps below using the portal or you can leverage the PowerShell scripts (CLI scripts coming)

**Details**
1. Create a resource group with a custom name
1. Create VNET1
   1. VNET range 10.1.0.0/23
   1. Single Subnet named Subnet1 with range 10.1.0.0/25
