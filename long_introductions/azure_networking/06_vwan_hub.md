# Azure Virtual WAN hub
We will now create global Virtual WAN architecture with hubs in two regions, interconnect all our VNETs and bring onpremises connections via VPN and BGP.

First let's create vwan, hubs and gateways (there are gateways for S2S VPN, Express Route which is private connectivity option eg. via Equinix or your telco and P2S VPN - note some 3rd party SD-WAN solutions are also supported as part of this ecosystem).

```bash
# Create vWAN
az network vwan create -n $prefix-vwan -g $prefix-central --type Standard

# Create Hub in northeurope
az network vhub create -n $prefix-ne-hub \
    -g $prefix-central \
    --vwan $prefix-vwan \
    --address-prefix 10.0.1.0/24 \
    --sku Standard \
    --location northeurope \
    --no-wait


# Create Hub in eastus
az network vhub create -n $prefix-us-hub \
    -g $prefix-central \
    --vwan $prefix-vwan \
    --address-prefix 10.0.2.0/24 \
    --sku Standard \
    --location eastus \
    --no-wait

# Create VPN gateway in eastus hub
az network vpn-gateway create -n $prefix-vpn -g $prefix-central --vhub $prefix-us-hub --location eastus --no-wait
```

When both hubs are ready (can take about 30 minutes) add project1 and project2 VNET to northeurope hub and test connectivity.

```bash
# Add project1 to hub
az network vhub connection create -n project1conn \
    -g $prefix-central \
    --vhub-name $prefix-ne-hub \
    --remote-vnet $(az network vnet show -n $prefix-project1 -g $prefix-project1 --query id -o tsv)

# Add project2 to hub
az network vhub connection create -n project2conn \
    -g $prefix-central \
    --vhub-name $prefix-ne-hub \
    --remote-vnet $(az network vnet show -n $prefix-project2 -g $prefix-project2 --query id -o tsv)

# Check routes on VM NIC now
az network nic show-effective-route-table -g $prefix-project2 -n $prefix-vmVMNic -o table

# Test connectivity
# Do this from project2 vm
ping 10.1.0.10      # SUCCESS
```

We will now simulate on-prem environment by using Linux VM as router and connect it to hub using S2S VPN with BGP.

```bash
# Create onprem Resource Group
az group create -n $prefix-onprem -l eastus

# Create VNET
az network vnet create -n $prefix-onprem -g $prefix-onprem --address-prefix 192.168.0.0/24

# Create subnets
az network vnet subnet create -n vpn -g $prefix-onprem --vnet-name $prefix-onprem --address-prefixes 192.168.0.0/24

# Create VM with Public IP
az vm create -n $prefix-vpn \
    -g $prefix-onprem \
    --image Ubuntu2204 \
    --vnet-name $prefix-onprem \
    --subnet vpn \
    --size Standard_B1s \
    --admin-username labuser \
    --admin-password Azure12345678 \
    --authentication-type password \
    --zone 1 \
    --private-ip-address 192.168.0.10 \
    --public-ip-address $prefix-vpn-ip \
    --nsg ""

# Configure onprem peer
az network vpn-site create --ip-address $(az network public-ip show -g $prefix-onprem -n $prefix-vpn-ip --query ipAddress -o tsv) \
    -n $prefix-onprem-site \
    -g $prefix-central \
    --address-prefixes 192.168.0.0/24 \
    --asn 65123 \
    --bgp-peering-address 192.168.0.10 \
    --virtual-wan $prefix-vwan
    
# Create VPN connection
az network vpn-gateway connection create -n $prefix-onprem-conn \
    -g $prefix-central \
    --gateway-name $prefix-vpn \
    --remote-vpn-site $(az network vpn-site show -n $prefix-onprem-site -g $prefix-central --query id -o tsv) \
    --shared-key Azure12345678 \
    --enable-bgp true 

# Capture gateway configs
## BGP AS number
az network vpn-gateway show -n $prefix-vpn -g $prefix-central --query bgpSettings.asn -o tsv

## First instance public IP 
az network vpn-gateway show -n $prefix-vpn -g $prefix-central --query bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0] -o tsv

## First instance BGP IP
az network vpn-gateway show -n $prefix-vpn -g $prefix-central --query bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses

# Enable serial access to all our VMs
az vm boot-diagnostics enable --ids $(az vm list -g $prefix-onprem --query "[].id" -o tsv)

# Connect to VM that will represent our onprem router and configure VPN and BGP
export prefix=klsl
az serial-console connect -n $prefix-vpn -g $prefix-onprem

# Do this from onprem VM
sudo -i
apt update
apt install frr frr-doc strongswan -y
export azureip=20.81.124.40   # Modify to fit yours!
export azurebgppeer=10.0.2.12   # Modify to fit yours!

cat > /etc/ipsec.conf << EOF
config setup
 
conn azure
        leftupdown=/etc/ipsec-notify.sh 
        authby=secret
        type=tunnel
        left=192.168.0.10
        leftid=$(curl ifconfig.io)
        leftsubnet=192.168.0.0/16
        right=$azureip
        rightsubnet=10.0.0.0/8
        auto=route
        keyexchange=ikev2
        leftauth=psk
        rightauth=psk
        ike=aes256-sha1-modp1024!
        ikelifetime=28800s
        aggressive=no
        esp=aes256-sha1!
        lifetime=3600s
        keylife=3600s
EOF

cat > /etc/ipsec.secrets << EOF
# In this case, we use a PSK. Format: Local.public.ip.address remote.public.ip.address : PSK 'custompresharedkey'
$(curl ifconfig.io) $azureip : PSK 'Azure12345678' 
EOF

cat > /etc/ipsec-notify.sh << EOF
#!/bin/bash
# Credit to Endre Szabó https://end.re/2015-01-06_vti-tunnel-interface-with-strongswan.html

set -o nounset
set -o errexit

VTI_IF="vti${PLUTO_UNIQUEID}"

case "${PLUTO_VERB}" in
    up-client)
        ip tunnel add "${VTI_IF}" local "${PLUTO_ME}" remote "${PLUTO_PEER}" mode vti \
            okey "${PLUTO_MARK_OUT%%/*}" ikey "${PLUTO_MARK_IN%%/*}"
        ip link set "${VTI_IF}" up
        ip route add 10.0.0.0/8 dev "${VTI_IF}"
        sysctl -w "net.ipv4.conf.${VTI_IF}.disable_policy=1"
        ;;
    down-client)
        ip tunnel del "${VTI_IF}"
        ;;
esac
EOF

ipsec restart
ipsec up azure
ping $azurebgppeer   # Ping BGP peer in Azure

# Configure BGP

cat > /etc/frr/bgpd.conf << EOF
!
! Zebra configuration saved from vty
!   2021/10/06 05:42:41
!
hostname bgpd
password zebra
log stdout
!
router bgp 65123
 bgp router-id 192.168.0.10
 network 192.168.0.0/24
 network 192.168.1.0/24
 network 192.168.2.0/24
 network 192.168.3.0/24
 neighbor $azurebgppeer remote-as 65515
 neighbor $azurebgppeer soft-reconfiguration inbound
!
 address-family ipv6
 exit-address-family
 exit
!
line vty
!
EOF

sed -i 's/bgpd=no/bgpd=yes/g' /etc/frr/daemons

service frr restart

vtysh << EOF
config
route-map ALLOW-ALL permit 100
router bgp 65123
 bgp router-id 192.168.0.10
 no bgp network import-check
 network 192.168.0.0/24
 network 192.168.1.0/24
 network 192.168.2.0/24
 network 192.168.3.0/24
 neighbor $azurebgppeer remote-as 65515
 neighbor $azurebgppeer soft-reconfiguration inbound
 neighbor $azurebgppeer route-map ALLOW-ALL in
 neighbor $azurebgppeer route-map ALLOW-ALL out
!
 address-family ipv6
 exit-address-family
 exit
!
exit
write memory
EOF

vtysh
show ip bgp
```
Now we can test connectivity onprem from our project2 which will go this path:

VM in project2 VNET -> HUB North Europe -> HUB East US -> IPSec tunnel to onprem -> onprem VM

```bash
# Check routes on VM NIC now
az network nic show-effective-route-table -g $prefix-project2 -n $prefix-vmVMNic -o table

# Test connectivity to onprem
# Do this from project2 vm
ping 192.168.0.10      # SUCCESS
```