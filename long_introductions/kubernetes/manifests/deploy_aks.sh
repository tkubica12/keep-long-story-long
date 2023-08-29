az group create -n klsl -l swedencentral
az aks create -n klsl -g klsl --node-count 3 --zones 1 2 3 --node-vm-size Standard_B2s -x --min-count 3 --max-count 5 --enable-cluster-autoscaler --network-policy azure
az aks get-credentials -n klsl -g klsl --admin