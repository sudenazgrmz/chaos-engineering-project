# Chaos Mesh - Complete Injection & Testing Guide

## 🎯 Quick Reference

### Check What's Running
```bash
# View all chaos experiments
kubectl get networkchaos,podchaos,httpchaos,stresschaos,iochaos,workflows -n chaos-demo

# Check pod status
kubectl get pods -n chaos-demo

# View application logs
kubectl logs -n chaos-demo -l app=frontend --tail=20
kubectl logs -n chaos-demo -l app=backend --tail=20
```

### Dashboard Access
```bash
# Already running at:
http://localhost:2333

# Or open with minikube:
minikube service chaos-dashboard -n chaos-mesh
```

---

## 📋 Available Endpoints to Test

### Frontend Service (Port 5000)
1. **GET /health** - Health check
2. **GET /** - Home page with endpoint list
3. **GET /api/data** - Calls backend, returns data
4. **POST /api/process** - Process JSON data via backend
5. **GET /api/slow** - Configurable delay endpoint
6. **GET /api/chain** - Makes 3 backend calls (test partial failures)

### Backend Service (Port 5001)
1. **GET /health** - Health check
2. **GET /data** - Returns JSON data
3. **POST /process** - Processes POST data
4. **GET /echo** - Echoes request details

---

## 🧪 Testing Scenarios

### SCENARIO 1: Network Delay Chaos

#### Step 1: Test WITHOUT Chaos (Baseline)
```bash
# Test latency (should be < 50ms)
time curl -s http://localhost:5000/api/data | jq '.latency_ms'

# Multiple requests to see average
for i in {1..5}; do
  echo "Request $i:"
  curl -s -w "Total time: %{time_total}s\n" http://localhost:5000/api/data | jq -c '{latency_ms}'
done
```

**Expected Output:**
```
Request 1: {"latency_ms":5.23}
Total time: 0.015s
Request 2: {"latency_ms":3.45}
Total time: 0.012s
```

#### Step 2: Apply Network Delay Chaos
```bash
kubectl apply -f - <<'CHAOS'
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-delay-test
  namespace: chaos-demo
spec:
  action: delay
  mode: all
  selector:
    namespaces:
      - chaos-demo
    labelSelectors:
      app: frontend
  delay:
    latency: "1000ms"    # 1 second delay
    jitter: "200ms"      # ±200ms variation
  direction: to
  target:
    selector:
      namespaces:
        - chaos-demo
      labelSelectors:
        app: backend
    mode: all
  duration: "3m"
CHAOS
```

#### Step 3: Test WITH Chaos
```bash
# Wait 5 seconds for chaos to take effect
sleep 5

# Test again (should show ~1000ms+ delay)
for i in {1..5}; do
  echo "Request $i:"
  curl -s -w "Total time: %{time_total}s\n" http://localhost:5000/api/data | jq -c '{latency_ms}'
done
```

**Expected Output:**
```
Request 1: {"latency_ms":1056.23}
Total time: 1.065s
Request 2: {"latency_ms":987.45}
Total time: 0.998s
```

#### Step 4: Cleanup
```bash
kubectl delete networkchaos network-delay-test -n chaos-demo
```

---

### SCENARIO 2: HTTP Response Replacement

#### Step 1: Normal Response
```bash
curl -s http://localhost:5000/api/data | jq '.backend_response.data'
```

**Expected Output:**
```json
{
  "items": [
    {"id": 1, "name": "Item A", "value": 42},
    {"id": 2, "name": "Item B", "value": 99},
    {"id": 3, "name": "Item C", "value": 55}
  ],
  "total": 3
}
```

#### Step 2: Inject HTTP Chaos
```bash
# Encode your malicious response
echo -n '{"status":"HACKED","message":"All your data are belong to us"}' | base64
# Output: eyJzdGF0dXMiOiJIQUNLRUQiLCJtZXNzYWdlIjoiQWxsIHlvdXIgZGF0YSBhcmUgYmVsb25nIHRvIHVzIn0=

kubectl apply -f - <<'CHAOS'
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: response-hack
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
  replace:
    body: eyJzdGF0dXMiOiJIQUNLRUQiLCJtZXNzYWdlIjoiQWxsIHlvdXIgZGF0YSBhcmUgYmVsb25nIHRvIHVzIn0=
  duration: "3m"
CHAOS
```

#### Step 3: Test Replaced Response
```bash
sleep 3
curl -s http://localhost:5000/api/data | jq '.backend_response'
```

**Expected Output:**
```json
{
  "status": "HACKED",
  "message": "All your data are belong to us"
}
```

#### Step 4: Cleanup
```bash
kubectl delete httpchaos response-hack -n chaos-demo
```

---

### SCENARIO 3: Pod Kill (Test Auto-Recovery)

#### Step 1: Check Current Pods
```bash
kubectl get pods -n chaos-demo -o wide
```

#### Step 2: Monitor Pods in Real-Time
```bash
# In a separate terminal, watch pods:
watch -n 1 'kubectl get pods -n chaos-demo'
```

#### Step 3: Apply Pod Kill Chaos
```bash
kubectl apply -f - <<'CHAOS'
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: pod-kill-test
  namespace: chaos-demo
spec:
  action: pod-kill
  mode: one          # Kill one random pod
  selector:
    namespaces:
      - chaos-demo
    labelSelectors:
      app: backend
CHAOS
```

#### Step 4: Test During Recovery
```bash
# Make requests while pod is recovering
for i in {1..10}; do
  echo "Request $i at $(date +%H:%M:%S):"
  curl -s -w "Status: %{http_code}\n" http://localhost:5000/api/data -o /dev/null
  sleep 2
done
```

**Expected Behavior:**
- Pod gets killed immediately
- Kubernetes starts new pod
- Some requests may fail (503) during recovery
- Service auto-recovers within 10-20 seconds

#### Step 5: Cleanup
```bash
kubectl delete podchaos pod-kill-test -n chaos-demo
```

---

### SCENARIO 4: POST Request Replacement

#### Step 1: Normal POST Request
```bash
curl -s -X POST http://localhost:5000/api/process \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","action":"login","timestamp":1234567890}' | jq .
```

**Expected Output:**
```json
{
  "message": "Processed 3 fields",
  "processed": true,
  "received": {
    "username": "alice",
    "action": "login",
    "timestamp": 1234567890
  }
}
```

#### Step 2: Inject Request Replacement
```bash
# Encode malicious payload
echo -n '{"sql":"DROP TABLE users;","injected":true}' | base64
# Output: eyJzcWwiOiJEUk9QIFRBQkxFIHVzZXJzOyIsImluamVjdGVkIjp0cnVlfQ==

kubectl apply -f - <<'CHAOS'
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: request-injection
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
  path: "/process"
  method: POST
  replace:
    body: eyJzcWwiOiJEUk9QIFRBQkxFIHVzZXJzOyIsImluamVjdGVkIjp0cnVlfQ==
  duration: "3m"
CHAOS
```

#### Step 3: Test Replaced Request
```bash
sleep 3

# Send normal request, but backend receives injected payload!
curl -s -X POST http://localhost:5000/api/process \
  -H "Content-Type: application/json" \
  -d '{"username":"alice","action":"login"}' | jq .
```

**Expected Output:**
```json
{
  "message": "Processed 2 fields",
  "processed": true,
  "received": {
    "sql": "DROP TABLE users;",
    "injected": true
  }
}
```

#### Step 4: Cleanup
```bash
kubectl delete httpchaos request-injection -n chaos-demo
```

---

### SCENARIO 5: Packet Loss

#### Step 1: Test Chain Endpoint (Makes 3 Backend Calls)
```bash
curl -s http://localhost:5000/api/chain | jq '.chain_results[] | {call, status, latency_ms}'
```

**Expected Output:**
```json
{"call":1,"status":"success","latency_ms":5.2}
{"call":2,"status":"success","latency_ms":3.8}
{"call":3,"status":"success","latency_ms":4.1}
```

#### Step 2: Apply 50% Packet Loss
```bash
kubectl apply -f - <<'CHAOS'
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: packet-loss-test
  namespace: chaos-demo
spec:
  action: loss
  mode: all
  selector:
    namespaces:
      - chaos-demo
    labelSelectors:
      app: frontend
  loss:
    loss: "50"        # 50% packet loss
    correlation: "25" # Burst losses
  direction: to
  target:
    selector:
      namespaces:
        - chaos-demo
      labelSelectors:
        app: backend
    mode: all
  duration: "3m"
CHAOS
```

#### Step 3: Test With Packet Loss
```bash
sleep 5

# Run multiple times to see failures
for i in {1..5}; do
  echo "=== Test $i ==="
  curl -s http://localhost:5000/api/chain | jq '.chain_results[] | {call, status}'
  echo ""
done
```

**Expected Output:**
```json
=== Test 1 ===
{"call":1,"status":"success"}
{"call":2,"status":"error"}
{"call":3,"status":"success"}

=== Test 2 ===
{"call":1,"status":"error"}
{"call":2,"status":"error"}
{"call":3,"status":"success"}
```

#### Step 4: Cleanup
```bash
kubectl delete networkchaos packet-loss-test -n chaos-demo
```

---

### SCENARIO 6: HTTP Error Injection (500 Errors)

#### Step 1: Apply HTTP 500 Error Chaos
```bash
kubectl apply -f - <<'CHAOS'
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: http-500-errors
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
  abort: true
  statusCode: 500
  duration: "3m"
CHAOS
```

#### Step 2: Test Error Responses
```bash
sleep 3

for i in {1..5}; do
  echo "Request $i:"
  curl -s -w "HTTP Status: %{http_code}\n" http://localhost:5000/api/data | head -1
done
```

**Expected Output:**
```
Request 1:
HTTP Status: 500

Request 2:
HTTP Status: 500
```

#### Step 3: Cleanup
```bash
kubectl delete httpchaos http-500-errors -n chaos-demo
```

---

### SCENARIO 7: CPU Stress Test

#### Step 1: Check Baseline Resource Usage
```bash
kubectl top pods -n chaos-demo
```

#### Step 2: Apply CPU Stress
```bash
kubectl apply -f - <<'CHAOS'
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: cpu-stress-test
  namespace: chaos-demo
spec:
  mode: all
  selector:
    namespaces:
      - chaos-demo
    labelSelectors:
      app: backend
  stressors:
    cpu:
      workers: 2      # 2 CPU stress workers
      load: 80        # 80% CPU load per worker
  duration: "3m"
CHAOS
```

#### Step 3: Test Performance During Stress
```bash
sleep 5

# Measure response times under load
for i in {1..10}; do
  time curl -s http://localhost:5000/api/data -o /dev/null
done
```

#### Step 4: Monitor Resource Usage
```bash
kubectl top pods -n chaos-demo
```

#### Step 5: Cleanup
```bash
kubectl delete stresschaos cpu-stress-test -n chaos-demo
```

---

## 🔥 Advanced: Combined Chaos Workflow

### Multi-Step Chaos Test
```bash
kubectl apply -f - <<'CHAOS'
apiVersion: chaos-mesh.org/v1alpha1
kind: Workflow
metadata:
  name: combined-chaos-test
  namespace: chaos-demo
spec:
  entry: serial-entry
  templates:
    - name: serial-entry
      templateType: Serial
      deadline: "10m"
      children:
        - delay-step
        - kill-step
        - stress-step
    
    - name: delay-step
      templateType: NetworkChaos
      deadline: "2m"
      networkChaos:
        action: delay
        mode: all
        selector:
          namespaces:
            - chaos-demo
          labelSelectors:
            app: frontend
        delay:
          latency: "500ms"
        direction: to
        target:
          selector:
            namespaces:
              - chaos-demo
            labelSelectors:
              app: backend
          mode: all
    
    - name: kill-step
      templateType: PodChaos
      deadline: "1m"
      podChaos:
        action: pod-kill
        mode: one
        selector:
          namespaces:
            - chaos-demo
          labelSelectors:
            app: backend
    
    - name: stress-step
      templateType: StressChaos
      deadline: "2m"
      stressChaos:
        mode: all
        selector:
          namespaces:
            - chaos-demo
          labelSelectors:
            app: backend
        stressors:
          cpu:
            workers: 1
            load: 50
CHAOS
```

### Monitor Workflow
```bash
# Watch workflow progress
kubectl get workflow combined-chaos-test -n chaos-demo -w

# Test continuously during workflow
while true; do
  echo "$(date +%H:%M:%S) - Status: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:5000/api/data)"
  sleep 2
done
```

---

## 🧹 Cleanup All Chaos

```bash
# Remove all chaos experiments
kubectl delete networkchaos --all -n chaos-demo
kubectl delete podchaos --all -n chaos-demo
kubectl delete httpchaos --all -n chaos-demo
kubectl delete stresschaos --all -n chaos-demo
kubectl delete iochaos --all -n chaos-demo
kubectl delete workflow --all -n chaos-demo

# Verify clean state
kubectl get networkchaos,podchaos,httpchaos,stresschaos -n chaos-demo
```

---

## 📊 Monitoring & Verification

### Quick Health Check
```bash
# Test all endpoints
curl -s http://localhost:5000/health && echo " ✓ Frontend healthy"
curl -s http://localhost:5000/api/data | jq -c '{status: "ok", latency: .latency_ms}' && echo " ✓ Backend healthy"
```

### Detailed Logs
```bash
# Watch frontend logs
kubectl logs -n chaos-demo -l app=frontend -f

# Watch backend logs
kubectl logs -n chaos-demo -l app=backend -f

# View chaos events
kubectl describe networkchaos -n chaos-demo
kubectl describe httpchaos -n chaos-demo
```

### Dashboard Metrics
Open http://localhost:2333 and navigate to:
- **Experiments** → See all active chaos
- **Events** → Real-time chaos events
- **Archives** → Historical experiment data

---

## 💡 Tips & Best Practices

1. **Always test baseline first** - Know normal behavior before chaos
2. **Start small** - Begin with short durations (1-2 minutes)
3. **Monitor pods** - Use `watch kubectl get pods -n chaos-demo`
4. **Check logs** - Look for errors during chaos: `kubectl logs -n chaos-demo -l app=backend --tail=50`
5. **Clean up** - Remove experiments after testing
6. **Use dashboard** - Visual feedback is easier than CLI

---

## 🆘 Troubleshooting

### Chaos not taking effect?
```bash
# Check if pods have chaos-mesh sidecar
kubectl get pods -n chaos-demo -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.chaos-mesh\.org/inject}{"\n"}{end}'

# Should show "true" for sidecar injection
```

### Port forward not working?
```bash
# Kill existing port-forwards
pkill -f "port-forward"

# Restart
kubectl port-forward -n chaos-demo svc/frontend-service 5000:5000 &
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333 &
```

### Experiments stuck?
```bash
# Force delete
kubectl delete httpchaos <name> -n chaos-demo --force --grace-period=0
```

---

## 📚 Reference

- Chaos Mesh Docs: https://chaos-mesh.org/docs/
- API Reference: https://chaos-mesh.org/docs/simulate-http-chaos-on-kubernetes/
- Dashboard: http://localhost:2333
- Application: http://localhost:5000
