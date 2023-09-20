# Cleanup

```bash
az group delete -n $prefix-project1 -y --no-wait
az group delete -n $prefix-project2 -y --no-wait
az group delete -n $prefix-central -y --no-wait
az group delete -n $prefix-onprem -y --no-wait
az group delete -n $prefix-shared -y --no-wait
```