"""
Backend Service for Chaos Mesh Demo
Simple service that the frontend calls - used to demonstrate network chaos
"""
from flask import Flask, request, jsonify
import time
import random
import os

app = Flask(__name__)

@app.route("/health")
def health():
    return jsonify({"status": "healthy", "service": "backend"})

@app.route("/data")
def get_data():
    """Returns sample data - target for network delay experiments"""
    return jsonify({
        "service": "backend",
        "timestamp": time.time(),
        "data": {
            "items": [
                {"id": 1, "name": "Item A", "value": random.randint(1, 100)},
                {"id": 2, "name": "Item B", "value": random.randint(1, 100)},
                {"id": 3, "name": "Item C", "value": random.randint(1, 100)}
            ],
            "total": 3
        }
    })

@app.route("/process", methods=["POST"])
def process():
    """Process incoming data"""
    data = request.get_json() or {}
    return jsonify({
        "service": "backend",
        "processed": True,
        "input_size": len(str(data)),
        "result": "OK"
    })

@app.route("/echo", methods=["POST"])
def echo():
    """Echo back the request - useful for seeing body modifications"""
    return jsonify({
        "method": request.method,
        "headers": dict(request.headers),
        "body": request.get_json(),
        "args": dict(request.args)
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)
