# 08 - Using managed services mapped to internal network via Private Endpoint
Applications will likely use managed services - let's make those mapped to internal network via Private Endpoint.

We will now create type of PaaS that runs on public endpoint - Azure Blob storage - and upload a file while allowing unauthenticated access to easily test things out.

```bash
# Create storage account
az storage account create -n ${prefix}store1155 -g $prefix-project2 --allow-blob-public-access

# Create public container
az storage container create -n public --account-name ${prefix}store1155 --public-access blob

# Create file and upload it
echo "Hello World" > hello.txt
az storage blob upload -f hello.txt -n hello.txt --container-name public --account-name ${prefix}store1155
rm hello.txt

# Access file from your PC via public endpoint
curl -L https://${prefix}store1155.blob.core.windows.net/public/hello.txt

# Check DNS response
dig ${prefix}store1155.blob.core.windows.net
```

When access this from project2 this does not work, because it is public endpoint and there is no explicit rule on our Azure Firewall.

```bash
# Do this from project2 VM
curl -L https://${prefix}store1155.blob.core.windows.net/public/hello.txt  # FAIL, blocked by Azure Firewall
dig ${prefix}store1155.blob.core.windows.net  # returns public IP
```

We will now configure Private Endpoint that will project this service into our VNET. Because service FQDN and its certificate remains the same, we will leverage private DNS zone with privatelink prefix so internal users will get response with private IP (while external users still get public IP so might still access the service unless you disable public access).

```bash
# Create Private Endpoint
az network private-endpoint create -n pe-storage --connection-name pe-storage \
    -g $prefix-project2 \
    --vnet-name $prefix-project2 \
    --subnet machines \
    --private-connection-resource-id $(az storage account show -n ${prefix}store1155 -g $prefix-project2 --query id -o tsv) \
    --group-id blob

# Create private DNS zone for blob storage private link
az network private-dns zone create \
    -g $prefix-central \
    -n "privatelink.blob.core.windows.net"

# Link this private DNS zone to shared services VNET where our DNS forwarder
az network private-dns link vnet create \
    -g $prefix-central \
    --zone-name "privatelink.blob.core.windows.net" \
    --name bloblink \
    --virtual-network $(az network vnet show -n $prefix-shared -g $prefix-shared --query id -o tsv) \
    --registration-enabled false

# Map your private endpoint to DNS zone group to automatically manage records
az network private-endpoint dns-zone-group create \
    -g $prefix-project2 \
    --endpoint-name pe-storage \
    --name  pe-storage-zonegroup \
    --private-dns-zone $(az network private-dns zone show -g $prefix-central -n "privatelink.blob.core.windows.net" --query id -o tsv) \
    --zone-name bloblink
```

Test connection from your project2 VM now.


```bash
# Do this from project2 VM
curl -L https://${prefix}store1155.blob.core.windows.net/public/hello.txt  # SUCCESS
dig ${prefix}store1155.blob.core.windows.net  # returns private IP
```

When accessing from onprem via VPN do not forget configure onprem DNS forwarder to send queries to blob.core.windows.net and privatelink.blob.core.windows.net to Azure DNS forwarder (inbound interface).