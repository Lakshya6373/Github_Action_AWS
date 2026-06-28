from flask import Flask, jsonify
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
import time

app = Flask(__name__)

# Prometheus metrics
REQUEST_COUNT = Counter(
    'app_request_count_total',
    'Total number of requests',
    ['method', 'endpoint', 'status']
)

REQUEST_LATENCY = Histogram(
    'app_request_latency_seconds',
    'Request latency in seconds',
    ['endpoint']
)

@app.route('/')
def home():
    start = time.time()
    REQUEST_COUNT.labels(method='GET', endpoint='/', status='200').inc()
    REQUEST_LATENCY.labels(endpoint='/').observe(time.time() - start)
    return jsonify({
        "message": "Hello from GitHub Actions + AWS ECS!",
        "status": "healthy",
        "version": "1.0.0"
    })

@app.route('/health')
def health():
    REQUEST_COUNT.labels(method='GET', endpoint='/health', status='200').inc()
    return jsonify({"status": "healthy"}), 200

@app.route('/metrics')
def metrics():
    return generate_latest(), 200, {'Content-Type': CONTENT_TYPE_LATEST}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
