# Public IP address
Most of the time in enterprise network we will not use direct connectivity on individual VMs, but rather centralized firewall (especially for outbound), some LB or WAF solution (inbound) or others.

```bash
# Connect to jump VM
export prefix=klsl
az serial-console connect -n $prefix-jump -g $prefix-project1

# From jump VM test connectivity to Internet
curl http://ifconfig.io/all   # You will see implicit outbound IP
```

We can also use:
- Outbound rules on LB
- NAT gateway
- Public IP on VM (this works for both inbound and outbound)

In all those cases outbound goes to Internet without any inspection by some special network device (such as Azure Firewall) which is reason why very often enterprises use secured hub with firewall capabilities to inspect such traffic.

Assign public ip to VM

```bash
# Create public IP
az network public-ip create -n $prefix-pip -g $prefix-project1 --sku Standard --zone 1 2 3

# Assign public IP to VM
az network nic ip-config update -g $prefix-project1 --nic-name $prefix-jumpVMNic --name ipconfig$prefix-jump --public-ip-address $prefix-pip

# Show ip
az network public-ip show -n $prefix-pip -g $prefix-project1 --query ipAddress -o tsv

# Do this in jump VM
curl http://ifconfig.io/all   # You will see assigned ip
ip a                          # But on interface there is still private one - Azure does 1:1 IP NAT
```

Advantage is full port spectrum to use (no SNAT), but therefore no shared IP. Also IP implicitly allows VM to expose ports (unless restricted with Network Security Group - our next topic).

Remove public IP from VM and use outbound rules on LB.

```bash
# Remove public IP from VM
az network nic ip-config update -g $prefix-project1 --nic-name $prefix-jumpVMNic --name ipconfig$prefix-jump --remove publicIpAddress

# Create LB with outbound rules, associate our front VMs, public IP
az network lb create -n $prefix-out-lb \
    -g $prefix-project1 \
    --sku Standard \
    --public-ip-address $prefix-pip \
    --backend-pool-name mypool

az network lb outbound-rule create -n myoutrule \
    -g $prefix-project1 \
    --lb-name $prefix-out-lb \
    --frontend-ip-configs loadBalancerFrontEnd \
    --protocol All \
    --address-pool mypool \
    --outbound-ports 20000 \
    --enable-tcp-reset true

az network nic ip-config update -g $prefix-project1 \
    --nic-name $prefix-front1VMNic \
    --name ipconfig$prefix-front1 \
    --lb-name $prefix-out-lb \
    --lb-address-pools mypool

az network nic ip-config update -g $prefix-project1 \
    --nic-name $prefix-front2VMNic \
    --name ipconfig$prefix-front2 \
    --lb-name $prefix-out-lb \
    --lb-address-pools mypool

# Check outbound IP
# Do this from front1 and from from2
curl http://ifconfig.io/all   # You will see LB IP
```

Advantage is shared IP, but therefore limited port spectrum (20000 ports). SNAT ports are allocated statically (range per VM). Another advantage is this solution is zone-redundant. For large-scale outbound (many VMs) you might consider NAT Gateway, but for zone redundancy you need to have 3 instances so it better for really advanced usecases. Nevertheless most enterprise networks no outbound SNAT on firewall device such as Azure Firewall.