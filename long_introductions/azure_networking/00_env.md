```bash
# COnfigure prifux

export prefix=klsl

# Connect to VMs
az serial-console connect -n $prefix-jump -g $prefix-project1   
az serial-console connect -n $prefix-front1 -g $prefix-project1
az serial-console connect -n $prefix-front2 -g $prefix-project1 
az serial-console connect -n $prefix-back -g $prefix-project1 
az serial-console connect -n $prefix-vm -g $prefix-project2
```