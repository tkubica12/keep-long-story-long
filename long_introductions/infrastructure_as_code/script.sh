#!/bin/bash
rg_name="myResourceGroup"
az group create --name $rg_name --location westeurope --tags "env=dev"
az network vnet create --name myVnet --resource-group $rg_name --address-prefixes 10.0.0.0/16
az network vnet subnet create --name mysubnet --resource-group $rg_name --vnet-name myVnet --address-prefixes 10.0.0.0/24

nics=(
    "nic1,10.0.0.4"
    "nic2,10.0.0.5"
)

for nic in "${nics[@]}"
do
    IFS=',' read -ra nic_info <<< "$nic"
    nic_name="${nic_info[0]}"
    private_ip="${nic_info[1]}"
    az network nic create --name $nic_name --resource-group $rg_name --vnet-name myVnet --subnet mysubnet --private-ip-address $private_ip
done