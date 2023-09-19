# VNET peering
We will now create different VNET and observe there is no connection to our first VNET. We will then create VNET peering to wire our VNETs together and enable communication between them.

```bash
# Configure prefix
export prefix=klsl

# Create resource group
az group create -n $prefix-project2 -l northeurope

# Create VNET
az network vnet create -n $prefix-project2 -g $prefix-project2 --address-prefix 10.2.0.0/16

# Create subnet
az network vnet subnet create -n machines -g $prefix-project2 --vnet-name $prefix-project2 --address-prefixes 10.2.0.0/24

# Deploy virtual machine (in bash)
az vm create -n $prefix-vm \
    -g $prefix-project2 \
    --image Ubuntu2204 \
    --vnet-name $prefix-project2 \
    --subnet machines \
    --size Standard_B1s \
    --admin-username labuser \
    --admin-password Azure12345678 \
    --authentication-type password \
    --zone 1 \
    --private-ip-address 10.2.0.10 \
    --public-ip-address "" \
    --nsg ""

# Enable serial access to all our new VMs
az vm boot-diagnostics enable --ids $(az vm list -g $prefix-project2 --query "[].id" -o tsv)

# Connect to VMs
export prefix=klsl
az serial-console connect -n $prefix-jump -g $prefix-project1   
az serial-console connect -n $prefix-front1 -g $prefix-project1
az serial-console connect -n $prefix-front2 -g $prefix-project1 
az serial-console connect -n $prefix-back -g $prefix-project1 
az serial-console connect -n $prefix-vm -g $prefix-project2

# Test connectivity from new VM to jump in first VNET
# Do this from project2 vm
export prefix=klsl
ping 10.1.0.10      # FAIL

# Check routes on VM NIC -> no peering = no routing to project1 VNET
az network nic show-effective-route-table -g $prefix-project2 -n $prefix-vmVMNic -o table
```

Let's now enable VNET peering and check connectivity again. Note VNET do NOT have to be in the same region.

```bash
# Peer from VNET1 to VNET2 and vice versa
az network vnet peering create -n project1-to-project2 \
    -g $prefix-project1 \
    --vnet-name $prefix-project1 \
    --remote-vnet $(az network vnet show -n $prefix-project2 -g $prefix-project2 --query id -o tsv) \
    --allow-vnet-access
az network vnet peering create -n project2-to-project1 \
    -g $prefix-project2 \
    --vnet-name $prefix-project2 \
    --remote-vnet $(az network vnet show -n $prefix-project1 -g $prefix-project1 --query id -o tsv) \
    --allow-vnet-access

# Check routes on VM NIC now
az network nic show-effective-route-table -g $prefix-project2 -n $prefix-vmVMNic -o table

# Test connectivity
# Do this from project2 vm
ping 10.1.0.10      # SUCCESS
```

Great! We now have direct access between VNETs therefore can seamlessly interconnect subscriptions and regions. But there are two issues here:
- DNS is not interconnected - we will solve this later
- There is no inspection of traffic on firewall, no central point of configuration. In order to do that we will remove direct peering between projects now and rather use some central hub with networking services to interconnect our VNETs.

```bash
# Remove peering
az network vnet peering delete -n project1-to-project2 -g $prefix-project1 --vnet-name $prefix-project1
az network vnet peering delete -n project2-to-project1 -g $prefix-project2 --vnet-name $prefix-project2