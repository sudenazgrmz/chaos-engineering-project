# Chaos Testing - Copy & Paste Curl Commands

## Quick Test Commands (No Chaos)

### Test Health
```bash
curl -s http://localhost:5000/health
```

### Test Basic Data Endpoint
```bash
curl -s http://localhost:5000/api/data | jq .
```

### Test POST Endpoint
```bash
curl -X POST http://localhost:5000/api/process \
  -H "Content-Type: application/json" \
  -d '{"user":"alice","count":42}' | jq .
```

### Measure Latency
```bash
curl -s -w "\nTime: %{time_total}s\n" http://localhost:5000/api/data | jq -c '{latency_ms}'
```

---

## Ready-to-Run Chaos Tests

### TEST 1: HTTP Response Replacement (Easiest!)

```bash
# Step 1: Inject chaos
kubectl apply -f - <<'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: hack-response
  namespace: chaos-demo
spec:
  mode: all
  selector:
    namespaces: [chaos-demo]
    labelSelectors: {app: backend}
  target: Response
  port: 5001
  path: "/data"
  method: GET
  replace:
    body: eyJIQUNLRUQiOnRydWUsIm1lc3NhZ2UiOiJZb3VyIGRhdGEgaXMgZ29uZSEifQ==
  duration: "5m"
EOF

# Step 2: Wait and test
sleep 5
curl -s http://localhost:5000/api/data | jq '.backend_response'

# Step 3: Cleanup
kubectl delete httpchaos hack-response -n chaos-demo
```

---

### TEST 2: Network Delay

```bash
# Inject 2-second delay
kubectl apply -f - <<'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: slow-network
  namespace: chaos-demo
spec:
  action: delay
  mode: all
  selector:
    namespaces: [chaos-demo]
    labelSelectors: {app: frontend}
  delay:
    latency: "2000ms"
  direction: to
  target:
    selector:
      namespaces: [chaos-demo]
      labelSelectors: {app: backend}
    mode: all
  duration: "5m"
EOF

# Test
sleep 5
time curl -s http://localhost:5000/api/data | jq -c '{latency_ms}'

# Cleanup
kubectl delete networkchaos slow-network -n chaos-demo
```

---

### TEST 3: HTTP 500 Errors

```bash
# Inject errors
kubectl apply -f - <<'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: error-500
  namespace: chaos-demo
spec:
  mode: all
  selector:
    namespaces: [chaos-demo]
    labelSelectors: {app: backend}
  target: Response
  port: 5001
  path: "/data"
  method: GET
  abort: true
  statusCode: 500
  duration: "5m"
EOF

# Test (should get errors)
sleep 5
for i in {1..5}; do
  curl -s -w "HTTP %{http_code}\n" http://localhost:5000/api/data -o /dev/null
done

# Cleanup
kubectl delete httpchaos error-500 -n chaos-demo
```

---

### TEST 4: Pod Kill & Auto-Recovery

```bash
# Kill a backend pod
kubectl apply -f - <<'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: kill-pod
  namespace: chaos-demo
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces: [chaos-demo]
    labelSelectors: {app: backend}
EOF

# Watch recovery
kubectl get pods -n chaos-demo -w

# Test during recovery
for i in {1..10}; do
  echo "Request $i:"
  curl -s -w "Status: %{http_code}\n" http://localhost:5000/api/data -o /dev/null
  sleep 2
done

# Cleanup
kubectl delete podchaos kill-pod -n chaos-demo
```

---

### TEST 5: POST Request Injection

```bash
# Inject SQL injection payload
kubectl apply -f - <<'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: inject-request
  namespace: chaos-demo
spec:
  mode: all
  selector:
    namespaces: [chaos-demo]
    labelSelectors: {app: backend}
  target: Request
  port: 5001
  path: "/process"
  method: POST
  replace:
    body: eyJzcWwiOiJEUk9QIFRBQkxFIHVzZXJzOyIsImluamVjdGVkIjp0cnVlfQ==
  duration: "5m"
EOF

# Send normal data, backend gets injected payload!
sleep 5
curl -X POST http://localhost:5000/api/process \
  -H "Content-Type: application/json" \
  -d '{"user":"alice"}' | jq '.received'

# Cleanup
kubectl delete httpchaos inject-request -n chaos-demo
```

---

## Monitoring Commands

### Check Active Chaos
```bash
kubectl get httpchaos,networkchaos,podchaos -n chaos-demo
```

### Check Pods
```bash
kubectl get pods -n chaos-demo -o wide
```

### Watch Pods Real-Time
```bash
watch -n 1 'kubectl get pods -n chaos-demo'
```

### View Logs
```bash
kubectl logs -n chaos-demo -l app=backend --tail=50
```

### Open Dashboard
```bash
open http://localhost:2333
```

---

## Clean Up Everything

```bash
kubectl delete httpchaos --all -n chaos-demo
kubectl delete networkchaos --all -n chaos-demo
kubectl delete podchaos --all -n chaos-demo
```

---

## Custom Payloads

### Create Your Own Base64 Payload
```bash
# Encode your custom JSON
echo -n '{"your":"data"}' | base64

# Common examples:
echo -n '{"HACKED":true}' | base64
# Output: eyJIQUNLRUQiOnRydWV9

echo -n '{"sql":"DROP TABLE users;"}' | base64
# Output: eyJzcWwiOiJEUk9QIFRBQkxFIHVzZXJzOyJ9
```

---

## Auto-Test Script

Run all tests automatically:
```bash
bash /tmp/test-chaos-scenarios.sh
```

Full documentation:
```bash
cat /tmp/CHAOS-INJECTION-GUIDE.md
```

Dashboard:
```bash
open http://localhost:2333
```
