"""
Chaos Mesh Demo Application
A simple Flask app to demonstrate various chaos engineering experiments
"""
from flask import Flask, request, jsonify
import requests
import time
import os
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configuration
BACKEND_SERVICE = os.getenv("BACKEND_SERVICE", "http://backend-service:5001")

@app.route("/health")
def health():
    """Health check endpoint"""
    return jsonify({"status": "healthy", "service": "frontend"})

@app.route("/")
def home():
    return jsonify({
        "message": "Chaos Mesh Demo App",
        "endpoints": [
            "/health - Health check",
            "/api/data - Get data (calls backend)",
            "/api/process - Process data with POST",
            "/api/slow - Intentionally slow endpoint",
            "/api/chain - Chain call to backend"
        ]
    })

@app.route("/api/data")
def get_data():
    """Endpoint that calls backend service - good for testing network delays"""
    start_time = time.time()
    try:
        response = requests.get(f"{BACKEND_SERVICE}/data", timeout=30)
        elapsed = time.time() - start_time
        return jsonify({
            "source": "frontend",
            "backend_response": response.json(),
            "latency_ms": round(elapsed * 1000, 2)
        })
    except requests.exceptions.Timeout:
        return jsonify({"error": "Backend timeout", "latency_ms": 30000}), 504
    except requests.exceptions.RequestException as e:
        return jsonify({"error": str(e)}), 503

@app.route("/api/process", methods=["POST"])
def process_data():
    """
    POST endpoint - good for testing HTTP body modification
    Chaos Mesh can modify the request/response body
    """
    data = request.get_json() or {}
    logger.info(f"Received data: {data}")
    
    # Process the data
    result = {
        "received": data,
        "processed": True,
        "timestamp": time.time(),
        "message": f"Processed {len(data)} fields"
    }
    return jsonify(result)

@app.route("/api/slow")
def slow_endpoint():
    """Endpoint with configurable delay - compare with chaos-injected delays"""
    delay = float(request.args.get("delay", 0.1))
    time.sleep(delay)
    return jsonify({
        "message": "Slow response",
        "intentional_delay_ms": delay * 1000
    })

@app.route("/api/chain")
def chain_call():
    """
    Makes multiple calls to backend - good for testing partial failures
    """
    results = []
    for i in range(3):
        try:
            start = time.time()
            resp = requests.get(f"{BACKEND_SERVICE}/data", timeout=10)
            elapsed = time.time() - start
            results.append({
                "call": i + 1,
                "status": "success",
                "latency_ms": round(elapsed * 1000, 2),
                "data": resp.json()
            })
        except Exception as e:
            results.append({
                "call": i + 1,
                "status": "failed",
                "error": str(e)
            })
    
    return jsonify({"chain_results": results})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
