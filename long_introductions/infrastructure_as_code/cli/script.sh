export RESOURCE_GROUP=long-introductions-rg
export LOCATION=westeurope

# Create resource group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create virtual network
az network vnet create \
    --resource-group $RESOURCE_GROUP \
    --name long-introductions-vnet \
    --address-prefixes 10.0.0.0/16

# Create subnet 1
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name long-introductions-vnet \
    --name sub1 \
    --address-prefixes 10.0.0.0/24

# Create subnet 2
az network vnet subnet create \
    --resource-group $RESOURCE_GROUP \
    --vnet-name long-introductions-vnet \
    --name sub1 \
    --address-prefixes 10.0.1.0/24

# Create NIC

# Array of NIC names
nic_names=("nic1" "nic2" "nic3")

# Loop through the array and create NICs
for nic_name in "${nic_names[@]}"
do
    az network nic create \
        --resource-group $RESOURCE_GROUP \
        --name $nic_name \
        --vnet-name long-introductions-vnet \
        --subnet sub1
done

