# Firewall
First let's see UI for what options to secure traffic are there including 3rd party solution.

Let's deploy Secured Hub (securing hub with Azure Firewall Premium).

```bash
# Create empty firewall policy
az network firewall policy create -n $prefix-fw-policy -g $prefix-central --sku Premium

# Create firewall
az network firewall create -n $prefix-fw \
    -g $prefix-central \
    --vhub $prefix-ne-hub \
    --public-ip-count 1 \
    --tier Premium \
    --sku AZFW_Hub \
    --firewall-policy $prefix-fw-policy
```

1. Try ```curl ifconfig.io``` from one of our VMs and see it worked. CHeck routing table

```bash
az network nic show-effective-route-table -g $prefix-project1 -n $prefix-jumpVMNic -o table
```

2. Configure route intent to send traffic towards Internet via firewall and try again - should fail. Check routing table.

```bash
az network nic show-effective-route-table -g $prefix-project1 -n $prefix-jumpVMNic -o table
```

3. Than configure L7 rule to allow it.