import os
from flask import Flask, render_template, send_from_directory, abort, request
from prometheus_client import Counter, Histogram, generate_latest
import time
import random
import logging

# Base directory containing index.html, css, js and images
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Ensure log directory exists
LOG_DIR = '/var/log/titan'
os.makedirs(LOG_DIR, exist_ok=True)

# Set up logging
log_formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')

info_handler = logging.FileHandler(os.path.join(LOG_DIR, 'info.log'))
info_handler.setLevel(logging.INFO)
info_handler.setFormatter(log_formatter)

error_handler = logging.FileHandler(os.path.join(LOG_DIR, 'error.log'))
error_handler.setLevel(logging.ERROR)
error_handler.setFormatter(log_formatter)

access_handler = logging.FileHandler(os.path.join(LOG_DIR, 'access.log'))
access_handler.setLevel(logging.INFO)
access_handler.setFormatter(log_formatter)

logging.basicConfig(level=logging.INFO, handlers=[info_handler, error_handler])
logger = logging.getLogger(__name__)

access_logger = logging.getLogger('access')
access_logger.setLevel(logging.INFO)
access_logger.addHandler(access_handler)

# Configure Flask to use this folder for templates and static files
app = Flask(__name__, static_folder=BASE_DIR, static_url_path='', template_folder=BASE_DIR)

# Prometheus metrics (minimal: count + latency per endpoint)
REQUEST_COUNT = Counter('http_requests_total', 'Total HTTP Requests', ['endpoint'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'Request latency', ['endpoint'])
                            
@app.route('/')
def index():
    logger.info('Index page accessed')
    REQUEST_COUNT.labels(endpoint='/').inc()
    with REQUEST_LATENCY.labels(endpoint='/').time():
        time.sleep(random.uniform(0.1, 0.5))  # Optional sim delay
    # Serve the main HTML page
        return send_from_directory(BASE_DIR, 'index.html')

@app.route('/<path:filename>')
def serve_file(filename):
    # Prevent path traversal attacks
    if '..' in filename or filename.startswith('/'):
        logger.error(f'Path traversal attempt: {filename}')
        abort(404)
    logger.info(f'Serving file: {filename}')
    return send_from_directory(BASE_DIR, filename)

@app.route('/payment')
def payment():
    logger.info('Payment page accessed')
    REQUEST_COUNT.labels(endpoint='/payment').inc()
    with REQUEST_LATENCY.labels(endpoint='/payment').time():
        time.sleep(random.uniform(0.05, 0.2))
        return send_from_directory(BASE_DIR, 'payment.html')

@app.route('/metrics')
def metrics():
    logger.info('Metrics endpoint accessed')
    return generate_latest(), 200, {'Content-Type': 'text/plain'}

@app.after_request
def log_access(response):
    access_logger.info(f"{request.remote_addr} {request.method} {request.path} {response.status_code}")
    return response

if __name__ == '__main__':
    # Run on all interfaces so the app is reachable from other hosts if needed
    app.run(host='0.0.0.0', port=5000, debug=True)
