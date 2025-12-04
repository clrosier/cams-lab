# Gateway API with Cilium

This directory contains the Gateway API configuration for your cluster.

## What is Gateway API?

Gateway API is the successor to Ingress API, providing:
- **Role-oriented design**: Separates concerns between cluster operators and app developers
- **More expressive**: Supports header-based routing, weighted traffic splitting, etc.
- **Portable**: Works across different implementations (Cilium, Istio, etc.)
- **Type-safe**: Better API design with explicit types

## Architecture

```
Internet → LoadBalancer IP → Gateway → HTTPRoute → Service → Pods
```

### Key Components

1. **GatewayClass** (`gatewayclass.yaml`)
   - Defines which controller manages Gateways
   - Cluster-wide resource
   - In our case: `io.cilium/gateway-controller`

2. **Gateway** (`gateway.yaml`)
   - The actual ingress point (gets a LoadBalancer IP)
   - Defines listeners (HTTP on 80, HTTPS on 443)
   - Can be shared across multiple teams/namespaces

3. **HTTPRoute** (`example-httproute.yaml`)
   - Routes traffic from Gateway to Services
   - Similar to Ingress but much more powerful
   - Supports advanced routing: headers, query params, traffic splitting

## Usage Examples

### Basic HTTP Route

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
  namespace: default
spec:
  parentRefs:
    - name: home-gateway
  hostnames:
    - "myapp.example.com"
  rules:
    - backendRefs:
        - name: my-service
          port: 8080
```

### HTTPS with cert-manager

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: myapp-tls
  namespace: default
spec:
  secretName: myapp-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - myapp.example.com
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app-https
spec:
  parentRefs:
    - name: home-gateway
      sectionName: https  # Attach to HTTPS listener
  hostnames:
    - "myapp.example.com"
  rules:
    - backendRefs:
        - name: my-service
          port: 8080
```

### Path-Based Routing

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: multi-path-route
spec:
  parentRefs:
    - name: home-gateway
  hostnames:
    - "api.example.com"
  rules:
    # Route /api/v1/* to v1 service
    - matches:
        - path:
            type: PathPrefix
            value: /api/v1
      backendRefs:
        - name: api-v1-service
          port: 8080
    
    # Route /api/v2/* to v2 service
    - matches:
        - path:
            type: PathPrefix
            value: /api/v2
      backendRefs:
        - name: api-v2-service
          port: 8080
```

### Header-Based Routing

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: header-route
spec:
  parentRefs:
    - name: home-gateway
  hostnames:
    - "api.example.com"
  rules:
    # Route requests with "X-Version: beta" header to beta service
    - matches:
        - headers:
            - name: X-Version
              value: beta
      backendRefs:
        - name: api-beta-service
          port: 8080
    
    # Default route for all other requests
    - backendRefs:
        - name: api-stable-service
          port: 8080
```

### Traffic Splitting (Canary Deployments)

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: canary-route
spec:
  parentRefs:
    - name: home-gateway
  hostnames:
    - "app.example.com"
  rules:
    - backendRefs:
        # 90% traffic to stable version
        - name: app-stable
          port: 8080
          weight: 90
        # 10% traffic to canary version
        - name: app-canary
          port: 8080
          weight: 10
```

### Request Header Manipulation

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: header-manipulation
spec:
  parentRefs:
    - name: home-gateway
  rules:
    - filters:
        # Add custom headers
        - type: RequestHeaderModifier
          requestHeaderModifier:
            add:
              - name: X-Custom-Header
                value: my-value
            # Remove headers
            remove:
              - X-Debug-Header
      backendRefs:
        - name: my-service
          port: 8080
```

### Redirects

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: redirect-route
spec:
  parentRefs:
    - name: home-gateway
  hostnames:
    - "old-domain.com"
  rules:
    - filters:
        - type: RequestRedirect
          requestRedirect:
            hostname: new-domain.com
            statusCode: 301
```

## Advantages over Ingress

1. **Role Separation**
   - Cluster operators manage Gateway
   - Developers manage HTTPRoutes
   - No conflicts over shared Ingress resources

2. **More Routing Options**
   - Header matching
   - Query parameter matching
   - HTTP method matching
   - Traffic splitting/weighting

3. **Better TLS Handling**
   - Multiple certificates per Gateway
   - SNI support
   - Explicit TLS termination

4. **Cross-namespace References**
   - HTTPRoutes can reference Services in other namespaces (with ReferenceGrant)

5. **Built-in Request/Response Manipulation**
   - Add/remove/set headers
   - URL rewrites
   - Redirects

## Debugging

```bash
# Check Gateway status
kubectl get gateway home-gateway -o yaml

# Check HTTPRoute status
kubectl get httproute -A

# Get Gateway LoadBalancer IP
kubectl get gateway home-gateway -o jsonpath='{.status.addresses[0].value}'

# View Cilium Gateway pods (Envoy proxies)
kubectl get pods -n default -l gateway.networking.k8s.io/gateway-name=home-gateway

# Check Envoy configuration
kubectl logs -n default -l gateway.networking.k8s.io/gateway-name=home-gateway
```

## Resources

- [Gateway API Official Docs](https://gateway-api.sigs.k8s.io/)
- [Cilium Gateway API Guide](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/)
- [Gateway API Examples](https://github.com/kubernetes-sigs/gateway-api/tree/main/examples)
