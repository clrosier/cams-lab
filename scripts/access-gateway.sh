#!/bin/bash
# Helper script to access Cilium Gateway services over WiFi
# 
# Since L2 announcements don't work over WiFi (AP isolation),
# this script helps you access services via NodePort

# Get the NodePort for the gateway service
NODEPORT=$(kubectl get svc -n default cilium-gateway-home-gateway -o jsonpath='{.spec.ports[0].nodePort}')

# List of node IPs (update if your IPs change)
NODES=(
    "192.168.2.206"  # kube-controller01
    "192.168.2.226"  # kube-worker01
    "192.168.2.205"  # kube-worker02  
    "192.168.2.229"  # kube-worker03
)

echo "Cilium Gateway is accessible via NodePort $NODEPORT"
echo ""
echo "Access URLs:"
for node in "${NODES[@]}"; do
    echo "  http://$node:$NODEPORT/"
done
echo ""
echo "Example with Host header:"
echo "  curl -H 'Host: echo.local' http://${NODES[0]}:$NODEPORT/"
echo ""

# Test connectivity to first healthy node
echo "Testing connectivity to ${NODES[0]}:$NODEPORT..."
if curl -s -H "Host: echo.local" "http://${NODES[0]}:$NODEPORT/" --max-time 5 > /dev/null 2>&1; then
    echo "✓ Gateway is accessible!"
else
    echo "✗ Gateway is not responding. Trying other nodes..."
    for node in "${NODES[@]:1}"; do
        echo "  Testing $node:$NODEPORT..."
        if curl -s -H "Host: echo.local" "http://$node:$NODEPORT/" --max-time 5 > /dev/null 2>&1; then
            echo "  ✓ Gateway accessible at $node:$NODEPORT"
            exit 0
        fi
    done
    echo "✗ Gateway not accessible on any node"
    exit 1
fi
