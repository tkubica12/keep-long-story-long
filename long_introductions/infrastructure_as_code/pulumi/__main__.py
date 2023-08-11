"""An Azure RM Python Pulumi program"""

import pulumi
from pulumi_azure_native import resources, network

resource_group = resources.ResourceGroup("rg")

vnet = network.VirtualNetwork(
    "myVnet",
    address_space=network.AddressSpaceArgs(
        address_prefixes=["10.0.0.0/16"]
    ),
    location=resource_group.location,
    resource_group_name=resource_group.name
)

subnet1 = network.Subnet(
    "sub1",
    address_prefix="10.0.0.0/24",
    resource_group_name=resource_group.name,
    virtual_network_name=vnet.name
)

subnet2 = network.Subnet(
    "sub2",
    address_prefix="10.0.1.0/24",
    resource_group_name=resource_group.name,
    virtual_network_name=vnet.name
)

nic1 = network.NetworkInterface(
    "nic1",
    ip_configurations=[{
        "name": "ipconfig1",
        "subnet": network.SubResourceArgs(id=subnet1.id),
        "private_ip_address_allocation": "Dynamic"
    }],
    location=resource_group.location,
    resource_group_name=resource_group.name
)
