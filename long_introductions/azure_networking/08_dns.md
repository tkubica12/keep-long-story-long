# DNS
In order to provide private DNS zones for Azure as well as forwarding to onprem DNS and back we will now deploy Azure DNS resolver service. In Azure vWAN architecture this service cannot be in hub so we will deploy "shared services" spoke.

1. Prepare shared services VNET and connect it to hub.

```bash
# Create resource group
az group create -n $prefix-shared -l northeurope

# Create shared services VNET
az network vnet create -n $prefix-shared -g $prefix-shared --address-prefix 10.254.0.0/16

# Create subnets
az network vnet subnet create -n dns-in     -g $prefix-shared --vnet-name $prefix-shared --address-prefixes 10.254.0.0/24
az network vnet subnet create -n dns-out    -g $prefix-shared --vnet-name $prefix-shared --address-prefixes 10.254.1.0/24

# Add VNET to hub
az network vhub connection create -n sharedconn \
    -g $prefix-central \
    --vhub-name $prefix-ne-hub \
    --remote-vnet $(az network vnet show -n $prefix-shared -g $prefix-shared --query id -o tsv)
```

2. Create private DNS zone that will be used by all Azure VMs (not you might also create zone per region, zone per environment, zone per BU etc.)

```bash
# Create Private DNS zone
az network private-dns zone create -g $prefix-shared -n azure.$prefix.internal

# Link our VNETs and enable registration (automatic creation of VMs records)
# Include shared VNET where DNS resolver will be deployed
az network private-dns link vnet create -n project1 \
    --registration-enabled true \
    -g $prefix-shared \
    --virtual-network $(az network vnet show -n $prefix-project1 -g $prefix-project1 --query id -o tsv) \
    --zone-name azure.$prefix.internal
az network private-dns link vnet create -n project2 \
    --registration-enabled true \
    -g $prefix-shared \
    --virtual-network $(az network vnet show -n $prefix-project2 -g $prefix-project2 --query id -o tsv) \
    --zone-name azure.$prefix.internal
az network private-dns link vnet create -n shared \
    --registration-enabled true \
    -g $prefix-shared \
    --virtual-network $(az network vnet show -n $prefix-shared -g $prefix-shared --query id -o tsv) \
    --zone-name azure.$prefix.internal

```

3. Create DNS forwarder service for integration with onprem DNS

```bash
# Create DNS resolver
az dns-resolver create -n resolver \
    -g $prefix-shared \
    --id $(az network vnet show -n $prefix-shared -g $prefix-shared --query id -o tsv)

# Create inbound endpoint
cat > dnsin.json << EOF
[
    {
        "private-ip-address":"",
        "private-ip-allocation-method":"Dynamic",
        "id":"$(az network vnet subnet show -n dns-in -g $prefix-shared --vnet-name $prefix-shared --query id -o tsv)"
    }
]
EOF

az dns-resolver inbound-endpoint create -n dns-in \
    --dns-resolver-name resolver \
    -g $prefix-shared \
    --ip-configurations @dnsin.json

rm dnsin.json

# Create outbound endpoint
az dns-resolver outbound-endpoint create -n dns-out \
    --dns-resolver-name resolver \
    -g $prefix-shared \
    --id $(az network vnet subnet show -n dns-out -g $prefix-shared --vnet-name $prefix-shared --query id -o tsv)
```

4. Enable DNS proxy on Azure Firewall
5. Point VNETs in ne to Azure Firewall as DNS server