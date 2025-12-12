import os
import subprocess
import json
import threading
import time
import re
import requests
from flask import Flask, jsonify, request
from flask_cors import CORS

# This should be the very first import to ensure environment variables are loaded.
import config

from auth_middleware import validate_clerk_token
from process_manager import ProcessManager

WS_SCRCPY_PATH = os.path.join(os.getcwd(), "ws-scrcpy")

app = Flask(__name__)

# Configure CORS from environment variables
cors_origins = os.getenv('CORS_ORIGINS', 'http://localhost:3000').split(',')
CORS(app, origins=cors_origins, supports_credentials=True)

# Initialize process manager
process_manager = ProcessManager()



# Middleware to validate Clerk JWT token
@app.before_request
def authenticate_request():
    # Skip authentication for static files
    if request.path.startswith('/static'):
        return
    
    # Skip authentication for health check endpoint
    if request.path == '/health':
        return
        
    # Skip authentication for OPTIONS requests (CORS preflight)
    if request.method == 'OPTIONS':
        return
        
    # Validate Clerk token for all other endpoints
    try:
        validate_clerk_token(request)
    except Exception as e:
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 401

# Add CORS headers to all responses
@app.after_request
def after_request(response):
    response.headers.add('Access-Control-Allow-Origin', 'http://localhost:3000')
    response.headers.add('Access-Control-Allow-Headers', 'Content-Type,Authorization')
    response.headers.add('Access-Control-Allow-Methods', 'GET,PUT,POST,DELETE,OPTIONS')
    response.headers.add('Access-Control-Allow-Credentials', 'true')
    return response

# Welcome endpoint
@app.route('/')
def index():
    return jsonify({
        "status": "success",
        "message": "Welcome to the Magdroid Backend!"
    })

# Health check endpoint
@app.route('/health')
def health_check():
    return jsonify({"status": "healthy"}), 200

# ADB Endpoints
@app.route('/assign_tcpip')
def assign_tcpip():
    try:
        # Execute the assign_tcpip.sh script
        result = subprocess.run(
            ['./scripts/assign_tcpip.sh'],
            capture_output=True,
            text=True,
            cwd=os.path.dirname(os.path.abspath(__file__))
        )
        
        return jsonify({
            "status": "success",
            "output": result.stdout,
            "details": f"Script exited with code {result.returncode}"
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": "",
            "details": str(e)
        }), 500

@app.route('/get_adb_devices')
def get_adb_devices():
    try:
        # Execute adb devices command
        result = subprocess.run(
            ['adb', 'devices'],
            capture_output=True,
            text=True
        )
        
        # Sanitize output to ensure it's valid JSON
        output = result.stdout.strip()
        
        return jsonify({
            "status": "success",
            "output": output,
            "details": f"Command exited with code {result.returncode}"
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": "",
            "details": str(e)
        }), 500

@app.route('/get_mdns_services')
def get_mdns_services():
    try:
        # Execute adb mdns services command
        result = subprocess.run(
            ['adb', 'mdns', 'services'],
            capture_output=True,
            text=True
        )
        
        return jsonify({
            "status": "success",
            "output": result.stdout,
            "details": f"Command exited with code {result.returncode}"
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": "",
            "details": str(e)
        }), 500

@app.route('/connect_ip_devices')
def connect_ip_devices():
    try:
        # Execute the connect_ip_devices.sh script
        result = subprocess.run(
            ['./scripts/connect_ip_devices.sh'],
            capture_output=True,
            text=True,
            cwd=os.path.dirname(os.path.abspath(__file__))
        )
        
        return jsonify({
            "status": "success",
            "output": result.stdout,
            "details": f"Script exited with code {result.returncode}"
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": "",
            "details": str(e)
        }), 500

@app.route('/connect_device/<device_id>')
def connect_device(device_id):
    try:
        # Execute adb connect command
        connect_result = subprocess.run(
            ['adb', 'connect', device_id],
            capture_output=True,
            text=True
        )

        # Get updated device list
        devices_result = subprocess.run(
            ['adb', 'devices'],
            capture_output=True,
            text=True
        )

        return jsonify({
            "status": "success",
            "output": f"Connect result:\n{connect_result.stdout}\n\nDevices list:\n{devices_result.stdout}",
            "details": f"Commands exited with codes {connect_result.returncode} and {devices_result.returncode}"
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": "",
            "details": str(e)
        }), 500

@app.route('/disconnect_all_devices')
def disconnect_all_devices():
    try:
        # Execute command to disconnect all devices
        result = subprocess.run(
            ['bash', '-c', 'for i in $(adb devices | awk \'NR>1 {print $1}\'); do adb disconnect $i; done'],
            capture_output=True,
            text=True
        )

        # Get updated device list to show result
        devices_result = subprocess.run(
            ['adb', 'devices'],
            capture_output=True,
            text=True
        )

        return jsonify({
            "status": "success",
            "output": f"Disconnect result:\n{result.stdout}\n\nUpdated devices list:\n{devices_result.stdout}",
            "details": f"Commands exited with codes {result.returncode} and {devices_result.returncode}"
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": "",
            "details": str(e)
        }), 500

# ws-scrcpy Endpoints
@app.route('/run_ws_scrcpy')
def run_ws_scrcpy():
    try:
        if process_manager.is_process_running('ws-scrcpy'):
            return jsonify({
                "status": "success",
                "output": "ws-scrcpy is already running.",
                "details": "Process is already active"
            })

        # Optimization: Check if the 'dist' build already exists
        dist_path = os.path.join(WS_SCRCPY_PATH, 'dist', 'index.js')
        if os.path.exists(dist_path):
            start_command = ['node', 'dist/index.js']
            startup_message = "Starting ws-scrcpy from existing build..."
        else:
            start_command = ['npm', 'start']
            startup_message = "No build found. Running 'npm start' (this may take a minute)..."

        # print(startup_message) # Log to backend console
        process_manager.start_process(
            'ws-scrcpy',
            start_command,
            cwd=WS_SCRCPY_PATH
        )

        # Health check to see if the server is up
        max_retries = 20
        retry_delay = 3
        for i in range(max_retries):
            try:
                response = requests.get("http://localhost:9786", timeout=2)
                if response.status_code == 200:
                    return jsonify({
                        "status": "success",
                        "output": "ws-scrcpy is now running and responsive.",
                        "details": f"Service became active after approximately {i * retry_delay} seconds."
                    })
            except (requests.ConnectionError, requests.Timeout):
                time.sleep(retry_delay)
        
        total_time = max_retries * retry_delay
        return jsonify({
            "status": "error",
            "output": "ws-scrcpy process started, but did not become responsive in time.",
            "details": f"Health check timed out after {total_time} seconds. The process may be busy building."
        }), 500
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": "",
            "details": str(e)
        }), 500

@app.route('/stop_ws_scrcpy')
def stop_ws_scrcpy():
    try:
        # Stop ws-scrcpy process
        stopped = process_manager.stop_process('ws-scrcpy')
        
        if stopped:
            return jsonify({
                "status": "success",
                "output": "ws-scrcpy stopped successfully",
                "details": "Process terminated"
            })
        else:
            return jsonify({
                "status": "success",
                "output": "ws-scrcpy was not running",
                "details": "No active process found"
            })
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": "",
            "details": str(e)
        }), 500

# Cloudflared Tunnel Endpoints
@app.route('/start_scrcpy_tunnel')
def start_scrcpy_tunnel():
    try:
        # First ensure ws-scrcpy is running
        if not process_manager.is_process_running('ws-scrcpy'):

            dist_path = os.path.join(WS_SCRCPY_PATH, 'dist', 'index.js')
            if os.path.exists(dist_path):
                start_command = ['node', 'dist/index.js']
                startup_message = "Starting ws-scrcpy from existing build..."
            else:
                start_command = ['npm', 'start']
                startup_message = "No build found. Running 'npm start' (this may take a minute)..."
                
            process_manager.start_process(
                'ws-scrcpy',
                start_command,
                cwd=WS_SCRCPY_PATH
            )
            time.sleep(2)  # Give it time to start
        
        # Check if tunnel is already running
        if process_manager.is_process_running('cloudflared'):
            # Get existing URL if available
            public_url = process_manager.get_cloudflared_url()
            if public_url:
                return jsonify({
                    "status": "success",
                    "output": "Tunnel is already running",
                    "public_url": public_url,
                    "local_url": "ws://localhost:9786"
                })
        
        # For a temporary "Quick Tunnel", we don't use a token.
        # The command is `cloudflared tunnel --url <local-service-url>`
        # This is much simpler and avoids the cert.pem error.
        
        # Start cloudflared quick tunnel process
        process_manager.start_process(
            'cloudflared',
            ['cloudflared', 'tunnel', '--url', 'http://localhost:9786'],
            capture_output=True
        )
        
        # This will now wait for up to 20 seconds for the URL to be detected.
        public_url = process_manager.get_cloudflared_url()
        
        if public_url:
            return jsonify({
                "status": "success",
                "output": "Cloudflared tunnel is active.",
                "public_url": public_url,
                "local_url": "ws://localhost:9786"
            })
        else:
            return jsonify({
                "status": "error",
                "output": "Cloudflared tunnel started, but a public URL could not be detected in time.",
                "public_url": None,
                "local_url": "ws://localhost:9786"
            }), 500
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": "",
            "details": str(e)
        }), 500

@app.route('/start_named_tunnel', methods=['POST'])
def start_named_tunnel():
    """Starts a cloudflared tunnel using a provided token."""
    try:
        data = request.get_json()
        token = data.get('token')
        if not token:
            return jsonify({"status": "error", "output": "Tunnel token is required."}), 400

        if process_manager.is_process_running('cloudflared'):
            return jsonify({"status": "error", "output": "A tunnel process is already running."}), 409

        if not process_manager.is_process_running('ws-scrcpy'):
            run_ws_scrcpy()

        process_manager.start_process(
            'cloudflared',
            ['cloudflared', 'tunnel', 'run', '--token', token],
            capture_output=True
        )

        public_url = process_manager.get_cloudflared_url()
        
        if public_url:
            return jsonify({
                "status": "success",
                "output": "Named tunnel is active.",
                "public_url": public_url,
                "local_url": "ws://localhost:9786"
            })
        else:
            return jsonify({
                "status": "error",
                "output": "Named tunnel started, but a public URL could not be detected.",
                "public_url": None
            }), 500
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": str(e)
        }), 500

@app.route('/stop_scrcpy_tunnel')
def stop_scrcpy_tunnel():
    try:
        # Stop both the tunnel and the underlying ws-scrcpy service
        tunnel_stopped = process_manager.stop_process('cloudflared')
        scrcpy_stopped = process_manager.stop_process('ws-scrcpy')
        
        messages = []
        if tunnel_stopped:
            messages.append("Tunnel closed successfully.")
        else:
            messages.append("Tunnel was not running.")

        if scrcpy_stopped:
            messages.append("ws-scrcpy service stopped.")
        else:
            messages.append("ws-scrcpy service was not running.")

        # Return a null public_url to signal the frontend to clear the field.
        return jsonify({
            "status": "success",
            "output": " ".join(messages),
            "details": "Cleanup process finished.",
            "public_url": None
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": "",
            "details": str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)