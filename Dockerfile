FROM python:3.9-slim-buster

WORKDIR /app

# Install minimal dependencies
RUN apt-get update && apt-get install -y --no-install-recommends netcat && rm -rf /var/lib/apt/lists/*

# Create the app user
RUN useradd -m app

# Change to the app user's home directory
WORKDIR /home/app

# Create the start_services.py file using a heredoc
RUN cat > start_services.py <<'EOF'
import socket
import threading
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from time import sleep

def run_service_a():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('0.0.0.0', 3000))
        s.listen(1)
        conn, addr = s.accept()
        with conn:
            print(f"Service A connected by {addr}")
            while True:
                sleep(1)

def run_service_b():
    port = int(os.environ.get('PORT', 80))
    class SimpleHTTPRequestHandler(BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header("Content-type", "text/html")
            self.end_headers()
            self.wfile.write(b"<html><body>OK</body></html>")

    with socket.socket(socket.AF_INET6, socket.SOCK_STREAM) as s:
        s.bind(('::', port))
        s.listen(1)
        httpd = HTTPServer(('::', port), SimpleHTTPRequestHandler)
        httpd.serve_forever()

def wait_for_service(host, port, timeout=30):
    import time
    start_time = time.time()
    while True:
        try:
            with socket.create_connection((host, port), timeout=1):
                print(f"Service on {host}:{port} is up")
                return
        except (socket.timeout, socket.error):
            if time.time() - start_time >= timeout:
                raise Exception(f"Service on {host}:{port} did not start within {timeout} seconds")
            print(f"Waiting for service on {host}:{port}...")
            time.sleep(1)

if __name__ == "__main__":
    threading.Thread(target=run_service_a, daemon=True).start()
    wait_for_service('localhost', 3000)
    threading.Thread(target=run_service_b, daemon=True).start()

    while True:
        sleep(1)
EOF

# Change ownership of the script to the app user
RUN chown app:app start_services.py

# Expose port for service_b
EXPOSE 80

# Start services using the generated start_services.py script
USER app
CMD ["python", "start_services.py"]
