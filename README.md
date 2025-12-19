# Chaos Mesh Demo Application

A complete example demonstrating various Chaos Mesh experiments with a Python Flask application on Kubernetes.

## Architecture

```
┌─────────────────┐         ┌─────────────────┐
│    Frontend     │ ──────► │    Backend      │
│   (Flask app)   │         │  (Flask app)    │
│   Port: 5000    │         │   Port: 5001    │
└─────────────────┘         └─────────────────┘
        │                           │
        └───────────────────────────┘
                    │
            Chaos Mesh Experiments
```

## Prerequisites

- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl configured
- Helm 3.x (for Chaos Mesh installation)
- Docker (for building images)

## Quick Start

### 1. Install Chaos Mesh

```bash
# Add Chaos Mesh Helm repo
helm repo add chaos-mesh https://charts.chaos-mesh.org
helm repo update

# Create namespace
kubectl create ns chaos-mesh

# Install Chaos Mesh
helm install chaos-mesh chaos-mesh/chaos-mesh \
  --namespace=chaos-mesh \
  --set chaosDaemon.runtime=containerd \
  --set chaosDaemon.socketPath=/run/containerd/containerd.sock

# Verify installation
kubectl get pods -n chaos-mesh
```

### 2. Build and Deploy the Demo App

```bash
# Build the Docker image
cd app
docker build -t chaos-demo:latest .

# For minikube, load image into cluster
minikube image load chaos-demo:latest

# For kind
kind load docker-image chaos-demo:latest

# Deploy to Kubernetes
kubectl apply -f k8s/deployment.yaml

# Verify deployment
kubectl get pods -n chaos-demo
kubectl get svc -n chaos-demo
```

### 3. Test the Application

```bash
# Port forward to access frontend
kubectl port-forward -n chaos-demo svc/frontend-service 5000:5000 &

# Test endpoints
curl http://localhost:5000/
curl http://localhost:5000/health
curl http://localhost:5000/api/data
curl -X POST http://localhost:5000/api/process \
  -H "Content-Type: application/json" \
  -d '{"name":"test","value":123}'
curl http://localhost:5000/api/chain
```

## Chaos Experiments

### 1. Network Delay (01-network-delay.yaml)

Adds latency to network traffic between services.

```bash
# Apply 500ms delay
kubectl apply -f chaos-experiments/01-network-delay.yaml

# Test and observe latency
curl http://localhost:5000/api/data

# Check experiment status
kubectl get networkchaos -n chaos-demo

# Clean up
kubectl delete -f chaos-experiments/01-network-delay.yaml
```

**Experiments included:**
- `network-delay-experiment`: 500ms delay with 100ms jitter
- `network-delay-severe`: 2s delay for stress testing
- `network-bandwidth-limit`: Limit bandwidth to 1 Mbps

### 2. HTTP Chaos (02-http-chaos.yaml)

Modify HTTP requests and responses at the application layer.

```bash
# Apply HTTP body modification
kubectl apply -f chaos-experiments/02-http-chaos.yaml

# Test - you'll see modified responses
curl http://localhost:5000/api/data

# Clean up
kubectl delete -f chaos-experiments/02-http-chaos.yaml
```

**Experiments included:**
- `http-response-body-modify`: Replace entire response body
- `http-request-body-modify`: Modify incoming POST data
- `http-response-body-patch`: Patch (add fields to) JSON responses
- `http-delay-injection`: Add 3s delay at HTTP level
- `http-error-500`: Force HTTP 500 errors
- `http-partial-failure`: 50% of requests return 503
- `http-header-modify`: Add/modify response headers

### 3. Pod Chaos (03-pod-chaos.yaml)

Kill pods and containers to test recovery.

```bash
# Kill a random backend pod
kubectl apply -f chaos-experiments/03-pod-chaos.yaml

# Watch pods recover
kubectl get pods -n chaos-demo -w

# Clean up
kubectl delete -f chaos-experiments/03-pod-chaos.yaml
```

**Experiments included:**
- `pod-kill-backend`: Kill one random backend pod
- `pod-kill-backend-half`: Kill 50% of backend pods
- `pod-failure-experiment`: Make pod fail without killing
- `container-kill-backend`: Kill specific container
- `scheduled-pod-kill`: Periodic pod killing (every 5 min)

### 4. Network Partition (04-network-partition.yaml)

Simulate network failures and packet issues.

```bash
# Create network partition
kubectl apply -f chaos-experiments/04-network-partition.yaml

# Test - requests should fail
curl http://localhost:5000/api/data

# Clean up
kubectl delete -f chaos-experiments/04-network-partition.yaml
```

**Experiments included:**
- `network-partition`: Complete network isolation
- `network-packet-loss`: 30% packet loss
- `network-corrupt`: 10% packet corruption
- `network-duplicate`: 20% packet duplication
- `network-reorder`: 50% packet reordering

### 5. Stress Chaos (05-stress-chaos.yaml)

Inject CPU and memory stress.

```bash
# Apply CPU stress
kubectl apply -f chaos-experiments/05-stress-chaos.yaml

# Monitor resource usage
kubectl top pods -n chaos-demo

# Clean up
kubectl delete -f chaos-experiments/05-stress-chaos.yaml
```

**Experiments included:**
- `cpu-stress-backend`: 80% CPU load
- `memory-stress-backend`: Allocate 100Mi memory
- `combined-stress`: Both CPU and memory stress

### 6. IO Chaos (06-io-chaos.yaml)

Inject disk IO latency and errors.

```bash
# Apply IO latency
kubectl apply -f chaos-experiments/06-io-chaos.yaml

# Clean up
kubectl delete -f chaos-experiments/06-io-chaos.yaml
```

**Experiments included:**
- `io-latency-experiment`: 100ms disk latency
- `io-fault-experiment`: IO errors (errno 5)
- `io-attr-override`: Modify file permissions

## Running Experiments Individually

You can apply specific experiments by name:

```bash
# Apply only the network delay experiment
kubectl apply -f - <<EOF
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: quick-delay-test
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
    latency: "1s"
  direction: to
  target:
    selector:
      namespaces:
        - chaos-demo
      labelSelectors:
        app: backend
    mode: all
  duration: "1m"
EOF
```

## Monitoring

### Using Chaos Mesh Dashboard

```bash
# Port forward to Chaos Mesh dashboard
kubectl port-forward -n chaos-mesh svc/chaos-dashboard 2333:2333

# Access at http://localhost:2333
```

### Check Experiment Status

```bash
# List all experiments
kubectl get networkchaos,podchaos,httpchaos,stresschaos,iochaos -n chaos-demo

# Describe specific experiment
kubectl describe networkchaos network-delay-experiment -n chaos-demo

# Check events
kubectl get events -n chaos-demo --sort-by='.lastTimestamp'
```

## Clean Up

```bash
# Delete all chaos experiments
kubectl delete networkchaos,podchaos,httpchaos,stresschaos,iochaos --all -n chaos-demo

# Delete demo application
kubectl delete -f k8s/deployment.yaml

# Uninstall Chaos Mesh
helm uninstall chaos-mesh -n chaos-mesh
kubectl delete ns chaos-mesh
```

## Tips for HTTPChaos

HTTPChaos requires the chaos-mesh sidecar. Enable it by adding this annotation to your pods:

```yaml
metadata:
  annotations:
    chaos-mesh.org/inject: "true"
```

## Troubleshooting

1. **Experiments not taking effect:**
   - Check if Chaos Mesh pods are running: `kubectl get pods -n chaos-mesh`
   - Verify selectors match your pods: `kubectl get pods -n chaos-demo --show-labels`

2. **HTTPChaos not working:**
   - Ensure sidecar injection is enabled
   - Check if the port matches your application

3. **Permission issues:**
   - Chaos Mesh needs elevated privileges
   - Check RBAC settings if running in restricted environments

## References

- [Chaos Mesh Documentation](https://chaos-mesh.org/docs/)
- [Chaos Mesh GitHub](https://github.com/chaos-mesh/chaos-mesh)
- [Chaos Engineering Principles](https://principlesofchaos.org/)
