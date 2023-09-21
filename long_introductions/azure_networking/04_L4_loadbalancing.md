# L4 Load Balancing
Let's deploy web application to our servers and use Azure LB to load balance traffic.

First let's install web application on our front VMs.

```bash
# Configure prefix
export prefix=klsl

# Connect to VMs
export prefix=klsl
az serial-console connect -n $prefix-jump -g $prefix-project1   
az serial-console connect -n $prefix-front1 -g $prefix-project1
az serial-console connect -n $prefix-front2 -g $prefix-project1 
az serial-console connect -n $prefix-back -g $prefix-project1 

# Do this on front1
sudo apt update && sudo apt install -y nginx
echo "My WEB on node 1" | sudo tee /var/www/html/index.html

# Do this on front2
sudo apt update && sudo apt install -y nginx
echo "My WEB on node 2" | sudo tee /var/www/html/index.html

# Create LB
az network lb create -n $prefix-lb \
    -g $prefix-project1 \
    --sku Standard \
    --vnet-name $prefix-project1 \
    --subnet frontend \
    --frontend-ip-name $prefix-lb-frontend \
    --backend-pool-name $prefix-lb-backend \
    --private-ip-address 10.1.1.100

# Create health probe
az network lb probe create -n myprobe \
    -g $prefix-project1 \
    --lb-name $prefix-lb \
    --protocol tcp \
    --port 80

# Create rule
az network lb rule create -n webrule \
    -g $prefix-project1 \
    --lb-name $prefix-lb \
    --protocol tcp \
    --frontend-port 80 \
    --backend-port 80 \
    --frontend-ip-name $prefix-lb-frontend \
    --backend-pool-name $prefix-lb-backend \
    --probe-name myprobe \
    --idle-timeout 15 \
    --enable-tcp-reset true

# Add both NIC configs to backend pool
az network nic ip-config address-pool add \
    -g $prefix-project1 \
   --address-pool $prefix-lb-backend \
   --ip-config-name ipconfig${prefix}-front1 \
   --nic-name $prefix-front1VMNic \
   --lb-name $prefix-lb

az network nic ip-config address-pool add \
    -g $prefix-project1 \
   --address-pool $prefix-lb-backend \
   --ip-config-name ipconfig${prefix}-front2 \
   --nic-name $prefix-front2VMNic \
   --lb-name $prefix-lb

# Test balancer
# Do this from jump
while true; do curl 10.1.1.100 --local-port $[$RANDOM+20000]; sleep 0.1; done

# Look at front1 to check IP of incoming packets
# You will see client IP is not changed (10.1.0.10 - jump), no NAT on LB
# Destination IP is of the node (10.1.1.11), not some shared "cluster IP" (for that you would need to configure floating IP and than dst IP of the packet will be 10.1.1.100)
# Also show HA ports (eg. port 81)
sudo tcpdump port 80 -n   
```