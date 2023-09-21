# L7 Load Balancing with Web Application Firewall

We will prepare DMZ environment.

```bash
# Create resource group
az group create -n $prefix-dmz -l northeurope

# Create VNET
az network vnet create -n $prefix-dmz -g $prefix-dmz --address-prefix 10.253.0.0/16

# Create subnet
az network vnet subnet create -n machines -g $prefix-dmz --vnet-name $prefix-dmz --address-prefixes 10.253.0.0/24
az network vnet subnet create -n waf -g $prefix-dmz --vnet-name $prefix-dmz --address-prefixes 10.253.1.0/24

# Connect to hub
az network vhub connection create -n dmzconn \
    -g $prefix-central \
    --vhub-name $prefix-ne-hub \
    --remote-vnet $(az network vnet show -n $prefix-dmz -g $prefix-dmz --query id -o tsv)
```

Following steps will be configured in GUI.

1. Configure routing intent in firewall manager. This time we do not want inspection of outbound traffic on firewall (this is DMZ and we want to explose WAF directly there), but let's enable inspection on all private traffic.

2. Configure network rule to allow DMZ to talk to IP address of our L4 load balancer in project1 - 10.1.1.100

3. Deploy WAF with public IP and configure rules towards our application.