# Chaos Mesh Demo - Documentation Index

## 📂 Project Structure

```
chaos-mesh-demo/
├── README.md                              # Original project overview
├── DOCUMENTATION-INDEX.md                 # This file - navigation guide
├── CHAOS-INJECTION-GUIDE.md              # ⭐ Complete 7-scenario testing guide
├── CURL-COMMANDS-CHEATSHEET.md           # ⭐ Quick copy-paste curl commands
├── HTTP-REQUEST-REPLACEMENT-GUIDE.md     # ⭐ Deep dive into HTTP chaos
├── test-chaos.sh                          # Interactive test menu script
├── test-chaos-scenarios.sh                # ⭐ Automated testing script
├── quick-start-http-chaos.sh              # HTTP chaos quick start
├── app/                                   # Application source code
│   ├── app.py                            # Frontend Flask service
│   ├── backend.py                        # Backend Flask service
│   ├── Dockerfile                        # Container image config
│   └── requirements.txt                  # Python dependencies
├── k8s/                                   # Kubernetes manifests
│   └── deployment.yaml                   # K8s deployment config
└── chaos-experiments/                     # Chaos experiment definitions
    ├── 01-network-delay.yaml             # Network latency experiments
    ├── 02-http-chaos.yaml                # HTTP-level chaos
    ├── 03-pod-chaos.yaml                 # Pod/container failures
    ├── 04-network-partition.yaml         # Network isolation
    ├── 05-stress-chaos.yaml              # CPU/memory stress
    ├── 06-io-chaos.yaml                  # Disk I/O chaos
    ├── 07-workflows.yaml                 # Multi-step workflows
    └── http-request-replacement-examples.yaml  # HTTP injection examples
```

---

## 🚀 Quick Start

### 1. Start Here - Complete Testing Guide
```bash
cat CHAOS-INJECTION-GUIDE.md
```
**What's inside:**
- 7 complete chaos scenarios with step-by-step instructions
- Network delay, HTTP replacement, pod kill, packet loss, etc.
- Each scenario includes: inject → test → cleanup
- Real curl commands you can copy-paste
- Expected outputs for verification

### 2. Quick Reference - Curl Commands
```bash
cat CURL-COMMANDS-CHEATSHEET.md
```
**What's inside:**
- Ready-to-run curl commands
- 5 most common chaos tests
- Monitoring commands
- Custom payload creation
- One-liners for quick testing

### 3. HTTP Chaos Deep Dive
```bash
cat HTTP-REQUEST-REPLACEMENT-GUIDE.md
```
**What's inside:**
- Request/response replacement examples
- Base64 encoding guide
- JSON patching techniques
- HTTP error injection
- Real-world use cases

---

## 🧪 Testing Scripts

### Automated Tests (Recommended!)
```bash
./test-chaos-scenarios.sh
```
Runs 3 automated tests:
1. Baseline test (no chaos)
2. HTTP response replacement
3. POST request injection

### Interactive Menu
```bash
./test-chaos.sh
```
Interactive menu with options:
1. Baseline test
2. Network delay test
3. HTTP body modification
4. Packet loss test
5. Pod kill test
6. Run all tests

### HTTP Quick Start
```bash
./quick-start-http-chaos.sh
```
Creates a simple HTTP response replacement experiment.

---

## 📋 Pre-defined Chaos Experiments

Located in `chaos-experiments/` directory:

### Network Chaos
- **01-network-delay.yaml** - 500ms delay, 2s severe delay, bandwidth limits
- **04-network-partition.yaml** - Packet loss, corruption, duplication, reordering

### Application Chaos
- **02-http-chaos.yaml** - HTTP body modification, delays, errors, partial failures
- **http-request-replacement-examples.yaml** - Request/response injection examples

### Infrastructure Chaos
- **03-pod-chaos.yaml** - Pod kill, container kill, pod failure
- **05-stress-chaos.yaml** - CPU stress, memory stress
- **06-io-chaos.yaml** - Disk latency, IO errors

### Orchestrated Chaos
- **07-workflows.yaml** - Serial and parallel multi-step chaos workflows

Apply any experiment:
```bash
kubectl apply -f chaos-experiments/01-network-delay.yaml
```

---

## 🎯 Common Commands

### Check What's Running
```bash
kubectl get httpchaos,networkchaos,podchaos,stresschaos -n chaos-demo
```

### Check Application Status
```bash
kubectl get pods -n chaos-demo
curl -s http://localhost:5000/health
```

### View Chaos Dashboard
```bash
open http://localhost:2333
```

### Clean Up All Chaos
```bash
kubectl delete httpchaos,networkchaos,podchaos,stresschaos --all -n chaos-demo
```

---

## 📚 Documentation Files Guide

### 📄 CHAOS-INJECTION-GUIDE.md
**Purpose:** Complete testing guide with 7 scenarios
**When to use:** Learning how to test with chaos
**What you'll find:**
- Scenario 1: Network Delay Chaos
- Scenario 2: HTTP Response Replacement
- Scenario 3: Pod Kill (Auto-Recovery)
- Scenario 4: POST Request Replacement
- Scenario 5: Packet Loss
- Scenario 6: HTTP Error Injection
- Scenario 7: CPU Stress Test
- Advanced workflows
- Monitoring commands
- Troubleshooting guide

### 📄 CURL-COMMANDS-CHEATSHEET.md
**Purpose:** Quick reference for copy-paste commands
**When to use:** Quick testing without reading long docs
**What you'll find:**
- 5 ready-to-run chaos tests
- Each test has: inject → test → cleanup
- Monitoring commands
- Custom payload examples

### 📄 HTTP-REQUEST-REPLACEMENT-GUIDE.md
**Purpose:** Deep dive into HTTP-level chaos
**When to use:** Testing API resilience and data validation
**What you'll find:**
- Response body replacement
- Request body injection
- JSON patching
- HTTP error injection
- Base64 encoding guide
- Real-world use cases

---

## 🎓 Learning Path

### Beginner
1. Read `README.md` to understand the project
2. Run `./test-chaos-scenarios.sh` to see chaos in action
3. Browse `CURL-COMMANDS-CHEATSHEET.md` for quick commands

### Intermediate
1. Read `CHAOS-INJECTION-GUIDE.md` scenarios 1-3
2. Try each scenario manually with curl
3. Explore `chaos-experiments/` directory
4. Apply experiments: `kubectl apply -f chaos-experiments/02-http-chaos.yaml`

### Advanced
1. Read `HTTP-REQUEST-REPLACEMENT-GUIDE.md`
2. Create custom chaos experiments
3. Build workflows with `chaos-experiments/07-workflows.yaml`
4. Use Chaos Mesh dashboard for monitoring

---

## 🔗 Quick Links

- **Application:** http://localhost:5000
- **Chaos Dashboard:** http://localhost:2333
- **Official Docs:** https://chaos-mesh.org/docs/

---

## 💡 Tips

1. **Always test baseline first** - Know normal behavior before injecting chaos
2. **Start with HTTP chaos** - Easiest to see and understand
3. **Use the dashboard** - Visual feedback is clearer than CLI
4. **Clean up after testing** - Delete experiments when done
5. **Check logs** - Use `kubectl logs` to see what's happening

---

## 🆘 Need Help?

1. Check `CHAOS-INJECTION-GUIDE.md` troubleshooting section
2. View Chaos Mesh dashboard for real-time status
3. Check pod logs: `kubectl logs -n chaos-demo -l app=backend --tail=50`
4. Verify experiments: `kubectl describe httpchaos <name> -n chaos-demo`

---

## 📝 Quick Test

Try this right now:
```bash
# Test normal response
curl -s http://localhost:5000/api/data | jq '.backend_response.data'

# Inject chaos
kubectl apply -f chaos-experiments/http-request-replacement-examples.yaml

# Test again (wait 5 seconds first)
sleep 5
curl -s http://localhost:5000/api/data | jq '.backend_response'

# Cleanup
kubectl delete httpchaos --all -n chaos-demo
```

You should see the response get replaced with chaos data!

---

**Happy Chaos Engineering! 🚀**
