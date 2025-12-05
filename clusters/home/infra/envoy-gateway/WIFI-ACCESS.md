# WiFi LoadBalancer Access

## Problem
L2 announcements (ARP-based load balancing) don't work over WiFi due to AP isolation/client isolation features that prevent ARP spoofing.

## Solution
Use NodePort to access services since WiFi limits L2 announcements.

## Accessing the Gateway

The gateway is accessible via NodePort on any node:

```bash
# Controller node
curl -H "Host: echo.local" http://192.168.2.206:31113/

# Worker nodes  
curl -H "Host: echo.local" http://192.168.2.226:31113/
curl -H "Host: echo.local" http://192.168.2.205:31113/
curl -H "Host: echo.local" http://192.168.2.229:31113/
```

## Local /etc/hosts Setup

Add this to your local `/etc/hosts` (or C:\Windows\System32\drivers\etc\hosts on Windows):

```
192.168.2.206 echo.local home-gateway.local
```

Then access with:
```bash
curl http://echo.local:31113/
```

## Alternative: Use HAProxy Locally

Install HAProxy on your local machine and configure it to load balance across nodes:

```haproxy
frontend http_front
    bind *:80
    default_backend http_back

backend http_back
    balance roundrobin
    server controller 192.168.2.206:31113 check
    server worker1 192.168.2.226:31113 check
    server worker2 192.168.2.205:31113 check backup
    server worker3 192.168.2.229:31113 check backup
```

## Future Options

1. **If you get ethernet connectivity**: L2 announcements will work perfectly
2. **BGP**: If your router supports BGP, we can use BGP instead of L2
3. **External Load Balancer**: Use a dedicated LB appliance or VM with ethernet
