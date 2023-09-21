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

```bash
# Enable DNS proxy
az network firewall policy update --name $prefix-fw-policy \
    -g $prefix-central \
    --dns-servers $(az dns-resolver inbound-endpoint show -n dns-in --dns-resolver-name resolver -g $prefix-shared --query ipConfigurations[0].privateIpAddress -o tsv) \
    --enable-dns-proxy true
```

5. Point VNETs in ne to Azure Firewall as DNS server

```bash
firewall_ip=$(az network firewall show -n $prefix-fw -g $prefix-central --query hubIPAddresses.privateIPAddress -o tsv)
az network vnet update -n $prefix-project1 -g $prefix-project1 --dns-servers $firewall_ip
az network vnet update -n $prefix-project2 -g $prefix-project2 --dns-servers $firewall_ip
```

6. Test Azure zone

```bash
# Do this from jump
export prefix=klsl
dig $prefix-front1.azure.$prefix.internal
dig $prefix-vm.azure.$prefix.internal
```

7. DNS forwarding to onprem

```bash
# Get Azure DNS resolver inbound IP
az dns-resolver inbound-endpoint show -n dns-in --dns-resolver-name resolver -g $prefix-shared --query ipConfigurations[0].privateIpAddress -o tsv

# Do this from onprem VM
sudo -i

export prefix=klsl
export azure_dns_in_ip=10.254.0.4

apt install bind9 -y

cat > /etc/bind/named.conf.options << EOF
options {
        directory "/var/cache/bind";

        // Forwarder to public DNS (eg. OpenDNS)
        forwarders {
                208.67.222.222;
        };

        listen-on port 53 { any; };
        allow-query { any; };
        recursion yes;

        auth-nxdomain no;    # conform to RFC1035
};

# logging {
#         channel default_log {
#                 file "/var/log/bind/default.log";
#                 print-time yes;
#                 print-category yes;
#                 print-severity yes;
#                 severity info;
#         };

#         category default { default_log; };
#         category queries { default_log; };
# };
EOF

cat > /etc/bind/named.conf.local << EOF
// onprem zone
zone "onprem.$prefix.internal" {
  type master;
  file "/etc/bind/db.onprem";
};

// forward to Azure node for Azure zone
zone "azure.$prefix.internal" {
        type forward;
        forwarders {$azure_dns_in_ip;};
};
EOF

cat > /etc/bind/db.onprem << EOF
\$TTL 60
@            IN    SOA  localhost. root.localhost.  (
                          2015112501   ; serial
                          1h           ; refresh
                          30m          ; retry
                          1w           ; expiry
                          30m)         ; minimum
                   IN     NS    localhost.

localhost       A   127.0.0.1
myvm.onprem.$prefix.internal.    A       192.168.0.10
EOF

systemctl restart bind9

# Configure DNS forwarding in Azure resolver
az dns-resolver forwarding-ruleset create --name "myOnpremRules" \
    --resource-group $prefix-shared \
    --outbound-endpoints [{id:"$(az dns-resolver outbound-endpoint show --dns-resolver-name resolver -n dns-out -g $prefix-shared --query id -o tsv)"}]

az dns-resolver forwarding-rule create --ruleset-name myOnpremRules \
    -n onprem \
    --resource-group $prefix-shared \
    --domain-name "onprem.$prefix.internal." \
    --forwarding-rule-state "Enabled" \
    --target-dns-servers '[{"ipAddress":"192.168.0.10","port":53}]'

az dns-resolver vnet-link create --ruleset-name "myOnpremRules" \
    -n project1 \
    -g $prefix-shared \
    --id $(az network vnet show -n $prefix-project1 -g $prefix-project1 --query id -o tsv)

az dns-resolver vnet-link create --ruleset-name "myOnpremRules" \
    -n project2 \
    -g $prefix-shared \
    --id $(az network vnet show -n $prefix-project2 -g $prefix-project2 --query id -o tsv)

az dns-resolver vnet-link create --ruleset-name "myOnpremRules" \
    -n shared \
    -g $prefix-shared \
    --id $(az network vnet show -n $prefix-shared -g $prefix-shared --query id -o tsv)


# Do this from jump VM
dig myvm.onprem.$prefix.internal
```