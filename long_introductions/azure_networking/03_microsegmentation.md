# Microsegmnentation
Later we will use central firewall between projects and environments, but within project we want to deploy something simple and cheap to enable microsegmentation.

Because we selected traditional subnet structure we can add Network Security Groups to them. To prevent lateral movement let's make sure SSH to machines is only allowed from jump server subnet.

```bash
# Configure prefix
export prefix=klsl

# Create NSG
az network nsg create -n $prefix-nsg -g $prefix-project1
```

```bash
# Add SSH rules
az network nsg rule create -n allowSshFromJump \
    -g $prefix-project1 \
    --nsg-name $prefix-nsg \
    --priority 100 \
    --protocol Tcp \
    --source-address-prefixes 10.1.0.0/24 \
    --destination-address-prefixes VirtualNetwork \
    --destination-port-ranges 22 \
    --access Allow

az network nsg rule create -n denySsh \
    -g $prefix-project1 \
    --nsg-name $prefix-nsg \
    --priority 110 \
    --protocol Tcp \
    --destination-address-prefixes VirtualNetwork \
    --destination-port-ranges 22 \
    --access Deny
```

```bash
# Add NSGs to frontend and backend subnets
az network vnet subnet update -n frontend -g $prefix-project1 --vnet-name $prefix-project1 --nsg $prefix-nsg
az network vnet subnet update -n backend  -g $prefix-project1 --vnet-name $prefix-project1 --nsg $prefix-nsg
```

Test things our - you should be able to SSH from jump everywhere, but not from front to back.

```bash
# Connect to VMs
export prefix=klsl
az serial-console connect -n $prefix-jump -g $prefix-project1   
az serial-console connect -n $prefix-front1 -g $prefix-project1
az serial-console connect -n $prefix-front2 -g $prefix-project1 
az serial-console connect -n $prefix-back -g $prefix-project1 

# Test SSH from jump
export prefix=klsl
ssh $prefix-front1  # SUCCESS

# Test SSH from front1 to front2
export prefix=klsl
ssh $prefix-front2   # FAILS!
```

Sometimes we might want to place specific NSGs directly to VM and/or reference other VMs by some group rather than address or range. We will now add NSG to our backend system that will specifically allow DB port 1433 from individual frontend machines, not whole subnet.

```bash
# Do this on backend
while true; do echo "DB here!" | nc -q 1 -vl 1433; done

# Do this from front1 (should SUCCEED)
telnet 10.1.2.10 1433

# Do this from jump (should SUCCEED for now)
telnet 10.1.2.10 1433

# Create NSG for backend
az network nsg create -n $prefix-nsg-back -g $prefix-project1

# Create ASG (named object)
az network asg create -n $prefix-asg-front -g $prefix-project1

# Place front1 and front2 to ASG
az network nic ip-config update -n ipconfig${prefix}-front1 --nic-name $prefix-front1VMNic -g $prefix-project1 --application-security-groups $prefix-asg-front 
az network nic ip-config update -n ipconfig${prefix}-front2 --nic-name $prefix-front2VMNic -g $prefix-project1 --application-security-groups $prefix-asg-front 

# Add rules to NSG (in bash)
az network nsg rule create -n allowDbFromFront \
    -g $prefix-project1 \
    --nsg-name $prefix-nsg-back \
    --priority 100 \
    --protocol Tcp \
    --source-asgs $prefix-asg-front \
    --destination-address-prefixes VirtualNetwork \
    --destination-port-ranges 1433 \
    --access Allow

az network nsg rule create -n denyDb \
    -g $prefix-project1 \
    --nsg-name $prefix-nsg-back \
    --priority 110 \
    --protocol Tcp \
    --destination-address-prefixes VirtualNetwork \
    --destination-port-ranges 1433 \
    --access Deny

# Add NSG to backend NIC
az network nic update -n $prefix-backVMNic -g $prefix-project1 --network-security-group $prefix-nsg-back

# From jump
telnet 10.1.2.10 1433   # FAILS

# From front1
telnet 10.1.2.10 1433   # OK
```

Let's add monitoring capabilities. We will start by creating centralized Log Analytics workspace and Storage Account.

```bash
# Create central resource group
az group create -n $prefix-central -l northeurope

# Create Log Analytics workspace
az monitor log-analytics workspace create -n $prefix-mylogs -g $prefix-central -l northeurope

# Create Storage Account
az storage account create -n mylogs$prefix -g $prefix-central
```

Enable both RAW flow logging and traffic analytics.

```bash
# Enable flow logging and analytics
az network watcher flow-log create -n $prefix-nsg-flows \
    -l northeurope \
    --nsg $prefix-nsg \
    -g $prefix-project1 \
    --enabled true \
    --storage-account $(az storage account show -n mylogs$prefix -g $prefix-central --query id -o tsv) \
    --workspace $(az monitor log-analytics workspace show -n $prefix-mylogs -g $prefix-central --query id -o tsv) \
    --traffic-analytics true \
    --interval 10 \
    --log-version 2 \
    --retention 90
az network watcher flow-log create -n $prefix-nsg-back-flows \
    -l northeurope \
    --nsg $prefix-nsg-back \
    -g $prefix-project1 \
    --enabled true \
    --storage-account $(az storage account show -n mylogs$prefix -g $prefix-central --query id -o tsv) \
    --workspace $(az monitor log-analytics workspace show -n $prefix-mylogs -g $prefix-central --query id -o tsv) \
    --traffic-analytics true \
    --interval 10 \
    --log-version 2 \
    --retention 90        
```
