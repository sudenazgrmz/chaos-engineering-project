#!/bin/bash
# Quick Chaos Testing Script with curl commands

echo "╔══════════════════════════════════════════════════════╗"
echo "║     CHAOS MESH - QUICK TEST SCENARIOS                ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Test 1: Baseline
echo "━━━ TEST 1: BASELINE (No Chaos) ━━━"
echo "Command: curl -s http://localhost:5000/api/data | jq -c '{latency_ms}'"
echo "Result:"
curl -s http://localhost:5000/api/data | jq -c '{latency_ms: .latency_ms, data_count: .backend_response.data.total}'
echo ""

# Clean up any existing chaos
kubectl delete httpchaos --all -n chaos-demo 2>/dev/null || true

sleep 3

# Test 2: HTTP Response Replacement
echo "━━━ TEST 2: HTTP RESPONSE REPLACEMENT ━━━"
echo "Injecting chaos: Replacing backend response with HACKED data..."

echo -n '{"HACKED":true,"message":"Your data has been compromised!"}' | base64 > /tmp/hack.b64

kubectl apply -f - <<EOF >/dev/null
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: demo-hack
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
    body: $(cat /tmp/hack.b64)
  duration: "2m"
EOF

echo "Waiting 5 seconds for chaos to activate..."
sleep 5

echo ""
echo "Command: curl -s http://localhost:5000/api/data | jq '.backend_response'"
echo "Result:"
curl -s http://localhost:5000/api/data | jq '.backend_response'
echo ""
echo "✓ Notice the response is now HACKED!"
echo ""

# Cleanup
kubectl delete httpchaos demo-hack -n chaos-demo >/dev/null 2>&1

sleep 2

# Test 3: POST Request Injection
echo "━━━ TEST 3: POST REQUEST INJECTION ━━━"
echo "Injecting SQL injection payload into POST requests..."

echo -n '{"sql":"DROP TABLE users;","hacked":true}' | base64 > /tmp/inject.b64

kubectl apply -f - <<EOF >/dev/null
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: demo-inject
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
    body: $(cat /tmp/inject.b64)
  duration: "2m"
EOF

sleep 5

echo ""
echo "Command: curl -X POST http://localhost:5000/api/process -H 'Content-Type: application/json' -d '{\"user\":\"alice\"}'"
echo ""
echo "What we sent: {\"user\":\"alice\"}"
echo "What backend received:"
curl -s -X POST http://localhost:5000/api/process \
  -H "Content-Type: application/json" \
  -d '{"user":"alice"}' | jq '.received'
echo ""
echo "✓ Backend received our INJECTED payload instead!"
echo ""

# Cleanup
kubectl delete httpchaos demo-inject -n chaos-demo >/dev/null 2>&1

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "All tests completed! ✓"
echo ""
echo "More scenarios available in: /tmp/CHAOS-INJECTION-GUIDE.md"
echo "Dashboard: http://localhost:2333"
