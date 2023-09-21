# Frontdoor
As alternative to "box-based" WAF in form of Application Gateway we will use distributed application delivery solution (dynamic CDN) in its Premium form that supports private connectivity to origin (our web server behind internal load balancer - no public IP).

This will be configured in GUI.

1. Create Private Link Service on top of ILB
2. Create FD and use private link service. Do not forget to update route to send HTTP only only to our origin.