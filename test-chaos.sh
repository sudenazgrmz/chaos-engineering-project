#!/bin/bash
# Chaos Mesh Demo Test Script
# Run this to test the application with and without chaos

set -e

FRONTEND_URL="${FRONTEND_URL:-http://localhost:5000}"
NAMESPACE="chaos-demo"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to measure response time
measure_latency() {
    local url=$1
    # Use curl's built-in timing for cross-platform compatibility
    local response=$(curl -s -w "\n%{http_code}\n%{time_total}" "$url" 2>/dev/null)
    local http_code=$(echo "$response" | tail -2 | head -1)
    local time_total=$(echo "$response" | tail -1)
    # Get body by counting total lines and excluding last 2
    local total_lines=$(echo "$response" | wc -l)
    local body_lines=$((total_lines - 2))
    local body=$(echo "$response" | head -n $body_lines)
    # Convert seconds to milliseconds
    local latency=$(echo "$time_total * 1000" | bc | cut -d. -f1)

    echo "HTTP $http_code | ${latency}ms | $body"
}

# Test baseline without chaos
baseline_test() {
    log_info "Running baseline tests (no chaos)..."
    echo "----------------------------------------"
    
    log_info "Testing /health endpoint:"
    measure_latency "$FRONTEND_URL/health"
    
    log_info "Testing /api/data endpoint:"
    measure_latency "$FRONTEND_URL/api/data"
    
    log_info "Testing /api/chain endpoint:"
    measure_latency "$FRONTEND_URL/api/chain"
    
    log_info "Testing POST /api/process endpoint:"
    curl -s -X POST "$FRONTEND_URL/api/process" \
        -H "Content-Type: application/json" \
        -d '{"test":"data","count":42}' | jq .
    
    echo "----------------------------------------"
}

# Test with network delay
test_network_delay() {
    log_info "Testing with network delay..."
    
    # Apply delay experiment
    kubectl apply -f - <<EOF
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: test-delay
  namespace: $NAMESPACE
spec:
  action: delay
  mode: all
  selector:
    namespaces:
      - $NAMESPACE
    labelSelectors:
      app: frontend
  delay:
    latency: "500ms"
  direction: to
  target:
    selector:
      namespaces:
        - $NAMESPACE
      labelSelectors:
        app: backend
    mode: all
  duration: "2m"
EOF
    
    sleep 5  # Wait for experiment to take effect
    
    log_info "Testing /api/data with 500ms delay:"
    for i in {1..5}; do
        measure_latency "$FRONTEND_URL/api/data"
    done
    
    # Clean up
    kubectl delete networkchaos test-delay -n $NAMESPACE
    log_info "Cleaned up network delay experiment"
}

# Test with HTTP body modification
test_http_body_modification() {
    log_info "Testing with HTTP response body modification..."
    
    # Note: HTTPChaos requires sidecar injection
    kubectl apply -f - <<EOF
apiVersion: chaos-mesh.org/v1alpha1
kind: HTTPChaos
metadata:
  name: test-body-mod
  namespace: $NAMESPACE
spec:
  mode: all
  selector:
    namespaces:
      - $NAMESPACE
    labelSelectors:
      app: backend
  target: Response
  port: 5001
  path: "/data"
  method: GET
  replace:
    body: '{"chaos":"injected","message":"Response replaced by Chaos Mesh"}'
  duration: "2m"
EOF
    
    sleep 5
    
    log_info "Testing /api/data with body replacement:"
    curl -s "$FRONTEND_URL/api/data" | jq .
    
    # Clean up
    kubectl delete httpchaos test-body-mod -n $NAMESPACE
    log_info "Cleaned up HTTP body modification experiment"
}

# Test with packet loss
test_packet_loss() {
    log_info "Testing with 30% packet loss..."
    
    kubectl apply -f - <<EOF
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: test-packet-loss
  namespace: $NAMESPACE
spec:
  action: loss
  mode: all
  selector:
    namespaces:
      - $NAMESPACE
    labelSelectors:
      app: frontend
  loss:
    loss: "30"
  direction: to
  target:
    selector:
      namespaces:
        - $NAMESPACE
      labelSelectors:
        app: backend
    mode: all
  duration: "2m"
EOF
    
    sleep 5
    
    log_info "Testing /api/chain with packet loss (expect some failures):"
    for i in {1..5}; do
        curl -s "$FRONTEND_URL/api/chain" | jq '.chain_results[] | {call, status, latency_ms}'
        echo "---"
    done
    
    # Clean up
    kubectl delete networkchaos test-packet-loss -n $NAMESPACE
    log_info "Cleaned up packet loss experiment"
}

# Test pod kill
test_pod_kill() {
    log_info "Testing pod kill..."
    
    log_info "Current pods:"
    kubectl get pods -n $NAMESPACE
    
    kubectl apply -f - <<EOF
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: test-pod-kill
  namespace: $NAMESPACE
spec:
  action: pod-kill
  mode: one
  selector:
    namespaces:
      - $NAMESPACE
    labelSelectors:
      app: backend
EOF
    
    sleep 5
    
    log_info "Pods after chaos:"
    kubectl get pods -n $NAMESPACE
    
    log_info "Testing /api/data during pod recovery:"
    for i in {1..5}; do
        measure_latency "$FRONTEND_URL/api/data"
        sleep 2
    done
    
    # Clean up
    kubectl delete podchaos test-pod-kill -n $NAMESPACE 2>/dev/null || true
    log_info "Cleaned up pod kill experiment"
}

# Main menu
main() {
    echo "========================================"
    echo "   Chaos Mesh Demo Test Script"
    echo "========================================"
    echo ""
    echo "Select a test to run:"
    echo "  1. Baseline test (no chaos)"
    echo "  2. Network delay test"
    echo "  3. HTTP body modification test"
    echo "  4. Packet loss test"
    echo "  5. Pod kill test"
    echo "  6. Run all tests"
    echo "  0. Exit"
    echo ""
    read -p "Enter choice [0-6]: " choice
    
    case $choice in
        1) baseline_test ;;
        2) test_network_delay ;;
        3) test_http_body_modification ;;
        4) test_packet_loss ;;
        5) test_pod_kill ;;
        6) 
            baseline_test
            test_network_delay
            test_packet_loss
            test_pod_kill
            ;;
        0) exit 0 ;;
        *) log_error "Invalid choice"; exit 1 ;;
    esac
}

# Check prerequisites
check_prereqs() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        log_error "curl not found"
        exit 1
    fi
    
    # Check if namespace exists
    if ! kubectl get namespace $NAMESPACE &> /dev/null; then
        log_error "Namespace $NAMESPACE not found. Deploy the app first."
        exit 1
    fi
}

check_prereqs
main
