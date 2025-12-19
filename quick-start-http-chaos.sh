#!/bin/bash
# Quick Start: HTTP Request/Response Replacement

echo "==================================="
echo "HTTP Chaos - Quick Start Guide"
echo "==================================="
echo ""

# Example 1: Replace Response Body
echo "Creating: Response Body Replacement Experiment..."
kubectl apply -f - <<'EOF'
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: demo-response-replace
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
    body: eyJjaGFvcyI6IlJlc3BvbnNlIFJlcGxhY2VkISIsImRhdGEiOiJIQUNLRUQifQ==
  duration: "5m"
EOF

echo ""
echo "✅ Experiment created!"
echo ""
echo "Test it:"
echo "  curl http://localhost:5000/api/data | jq ."
echo ""
echo "View in dashboard:"
echo "  http://localhost:2333"
echo ""
echo "Cleanup when done:"
echo "  kubectl delete httpchaos demo-response-replace -n chaos-demo"
