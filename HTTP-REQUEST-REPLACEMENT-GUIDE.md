# HTTP Request/Response Replacement with Chaos Mesh

## Overview
HTTP Chaos allows you to manipulate HTTP traffic at the application layer by replacing or modifying requests and responses. This is useful for testing:
- API resilience to malformed data
- Application behavior with corrupted responses
- Security vulnerabilities (injection attacks)
- Data validation logic

## Prerequisites
Pods must have the Chaos Mesh sidecar injected:
```yaml
metadata:
  annotations:
    chaos-mesh.org/inject: "true"
```

## Example 1: Replace Response Body ✅ WORKING

### YAML Configuration
```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: replace-response-body
  namespace: chaos-demo
spec:
  mode: all
  selector:
    namespaces:
      - chaos-demo
    labelSelectors:
      app: backend
  target: Response          # Intercept outgoing responses
  port: 5001
  path: "/data"
  method: GET
  replace:
    # Base64 encoded JSON: {"chaos":"Response Replaced!","data":"HACKED"}
    body: eyJjaGFvcyI6IlJlc3BvbnNlIFJlcGxhY2VkISIsImRhdGEiOiJIQUNLRUQifQ==
  duration: "5m"
```

### How to Apply
```bash
kubectl apply -f replace-response-body.yaml
```

### Test It
```bash
curl http://localhost:5000/api/data | jq .
```

### Expected Result
```json
{
  "backend_response": {
    "chaos": "Response Replaced!",
    "data": "HACKED"
  },
  "latency_ms": 9.56,
  "source": "frontend"
}
```

**Normal response would contain items array, but chaos replaced it with malicious data!**

---

## Example 2: Patch Response Body (Add Fields) ✅ WORKING

### YAML Configuration
```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: patch-response-json
  namespace: chaos-demo
spec:
  mode: all
  selector:
    namespaces:
      - chaos-demo
    labelSelectors:
      app: backend
  target: Response
  port: 5001
  path: "/data"
  method: GET
  patch:
    body:
      type: JSON
      # Adds new fields to existing JSON response
      value: '{"chaos_injected":true,"warning":"Data may be corrupted","injection_time":"2025-12-08T12:00:00Z"}'
  duration: "5m"
```

### Result
Original response gets ADDITIONAL fields:
```json
{
  "chaos_injected": true,
  "warning": "Data may be corrupted",
  "injection_time": "2025-12-08T12:00:00Z",
  "data": {...}  // Original data preserved
}
```

---

## Example 3: Replace POST Request Body

### YAML Configuration
```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: replace-post-request
  namespace: chaos-demo
spec:
  mode: all
  selector:
    namespaces:
      - chaos-demo
    labelSelectors:
      app: backend
  target: Request           # Intercept incoming requests
  port: 5001
  path: "/process"
  method: POST
  replace:
    # Base64 encoded: {"chaos":"INJECTED","hacked":true,"count":999}
    body: eyJjaGFvcyI6IklOSkVDVEVEIiwiaGFja2VkIjp0cnVlLCJjb3VudCI6OTk5fQ==
  duration: "5m"
```

### Use Case
Test if your application validates incoming POST data properly. Even if client sends valid data, backend receives the chaos-injected payload.

---

## Example 4: HTTP Error Injection

### YAML Configuration
```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: http-error-500
  namespace: chaos-demo
spec:
  mode: all
  selector:
    namespaces:
      - chaos-demo
    labelSelectors:
      app: backend
  target: Response
  port: 5001
  path: "/data"
  method: GET
  abort: true               # Abort the request
  statusCode: 500           # Return HTTP 500
  duration: "3m"
```

---

## Example 5: HTTP Delay Injection

### YAML Configuration
```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: http-delay
  namespace: chaos-demo
spec:
  mode: all
  selector:
    namespaces:
      - chaos-demo
    labelSelectors:
      app: backend
  target: Request
  port: 5001
  path: "/data"
  method: GET
  delay: "3s"               # Add 3 second delay
  duration: "5m"
```

---

## Important Notes

### Base64 Encoding
Request/response bodies must be base64 encoded:
```bash
echo -n '{"chaos":"injected"}' | base64
# Output: eyJjaGFvcyI6ImluamVjdGVkIn0=
```

### Target Options
- `target: Request` - Intercepts incoming HTTP requests
- `target: Response` - Intercepts outgoing HTTP responses

### Selector Modes
- `mode: all` - Affects all matching pods
- `mode: one` - Affects one random pod
- `mode: fixed` - Affects specific number of pods
- `mode: fixed-percent` - Affects percentage of pods

### Path Matching
- Exact: `path: "/data"`
- Wildcard: `path: "/data*"`
- Regex: Use path matching patterns

---

## Viewing in Dashboard

Access the Chaos Mesh Dashboard at http://localhost:2333 to:
1. See all active HTTPChaos experiments
2. View real-time status and logs
3. Create new experiments via UI wizard
4. Monitor affected pods and requests

---

## Cleanup

Remove all HTTP chaos experiments:
```bash
kubectl delete httpchaos --all -n chaos-demo
```

---

## Real-World Use Cases

1. **Security Testing**: Inject SQL injection or XSS payloads in requests
2. **Data Validation**: Test if app handles corrupted/malformed responses
3. **API Contract Testing**: Verify client handles unexpected API changes
4. **Error Handling**: Test retry logic with intermittent 500 errors
5. **Performance Testing**: Add delays to simulate slow backend services
6. **Chaos Engineering**: Randomly replace 10% of responses to test resilience

---

## Active Experiments Status

```bash
kubectl get httpchaos -n chaos-demo
```

```
NAME                    DURATION
patch-response-json     5m
replace-post-request    5m
replace-response-body   5m
```

All experiments have 5-minute duration and will automatically stop.
