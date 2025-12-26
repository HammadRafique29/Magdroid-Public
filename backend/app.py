import os
import subprocess
import json
import threading
import time
import re
import requests
import socket
from flask import Flask, jsonify, request
from flask_cors import CORS

# This should be the very first import to ensure environment variables are loaded.
import config

from process_manager import ProcessManager

app = Flask(__name__)

# Configure CORS from environment variables
cors_origins = os.getenv('CORS_ORIGINS', 'http://localhost:3000').split(',')
print(cors_origins)
BACKEND_PORT = os.getenv('BACKEND_PORT', '5000')
WS_SCRCPY_PATH = os.path.join(os.getcwd(), "ws-scrcpy")

CORS(app, origins=cors_origins, supports_credentials=True)

# Initialize process manager
process_manager = ProcessManager()




# Add CORS headers to all responses

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
    """
    Executes 'adb devices' and filters the output based on the DEVICES_RANGE environment variable.
    This ensures that only devices within the specified IP range(s) are returned to the frontend.
    """
    try:
        # Execute adb devices command
        result = subprocess.run(
            ['adb', 'devices'],
            capture_output=True,
            text=True,
            check=True
        )
        
        # Get the allowed IP range from environment variables, with a default.
        devices_range_str = os.getenv('DEVICES_RANGE', "192.168.1.0/24")
        
        # Parse the raw output from 'adb devices'.
        raw_output = result.stdout.strip()
        lines = raw_output.split('\n')
        
        # The first line is always "List of devices attached", so we skip it.
        device_lines = lines[1:]
        
        # Filter devices based on the IP range.
        filtered_devices = []
        for line in device_lines:
            if not line.strip():
                continue
                
            # Device ID is the first part of the line.
            device_id = line.split('\t')[0]
            
            # Extract the IP address from the device ID (e.g., '192.168.1.10:5555').
            # This regex ensures we only match IP-based devices, not USB ones.
            match = re.match(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', device_id)
            
            if match:
                ip = match.group(1)
                # If the IP is in one of the allowed ranges, keep the device.
                if is_ip_in_range(ip, devices_range_str):
                    filtered_devices.append(line)
            else:
                # Keep non-IP devices (e.g., USB devices) as they are not subject to IP filtering.
                filtered_devices.append(line)

        # Reconstruct the output string with only the authorized devices.
        filtered_output = "List of devices attached\n" + "\n".join(filtered_devices)
        
        return jsonify({
            "status": "success",
            "output": filtered_output,
            "details": f"Command exited with code {result.returncode}"
        })
    except subprocess.CalledProcessError as e:
        return jsonify({
            "status": "error",
            "output": e.stderr,
            "details": f"ADB command failed with exit code {e.returncode}"
        }), 500
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": "An unexpected error occurred.",
            "details": str(e)
        }), 500


def is_ip_in_range(ip, ranges_str):
    """
    Checks if a given IP address is within any of the specified ranges.
    
    Args:
        ip (str): The IP address to check.
        ranges_str (str): A comma-separated string of ranges (CIDR, IP-IP, or single IP).
        
    Returns:
        bool: True if the IP is in any range, False otherwise.
    """
    import ipaddress

    try:
        ip_addr = ipaddress.ip_address(ip)
    except ValueError:
        # If the IP is invalid, it can't be in any valid range.
        return False

    for r in ranges_str.split(','):
        r = r.strip()
        if not r:
            continue
            
        try:
            # Handle CIDR format (e.g., "192.168.1.0/24")
            if '/' in r:
                net = ipaddress.ip_network(r, strict=False)
                if ip_addr in net:
                    return True
            
            # Handle range format (e.g., "192.168.1.40-192.168.1.45")
            elif '-' in r:
                start_ip, end_ip = r.split('-')
                if ipaddress.ip_address(start_ip) <= ip_addr <= ipaddress.ip_address(end_ip):
                    return True
            
            # Handle single IP format
            else:
                if ip_addr == ipaddress.ip_address(r):
                    return True
        except ValueError:
            # Silently ignore malformed ranges in the config.
            # You might want to log this in a real application.
            continue
            
    return False

def is_port_available(port):
    """Check if a port is available."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        try:
            sock.bind(('localhost', port))
            return True
        except OSError:
            return False

def kill_process_on_port(port):
    """Find and kill the process using the specified port."""
    try:
        # Use lsof to find the process using the port
        result = subprocess.run(
            ['lsof', '-ti', f':{port}'],
            capture_output=True,
            text=True
        )
        if result.returncode == 0 and result.stdout.strip():
            pids = result.stdout.strip().split('\n')
            for pid in pids:
                try:
                    subprocess.run(['kill', '-9', pid], check=True)
                    print(f"Killed process {pid} using port {port}")
                except subprocess.CalledProcessError as e:
                    print(f"Failed to kill process {pid}: {e}")
            return True
        else:
            print(f"No process found using port {port}")
            return False
    except Exception as e:
        print(f"Error killing process on port {port}: {e}")
        return False

@app.route('/get_mdns_services')
def get_mdns_services():
    try:
        # Execute adb mdns services command
        result = subprocess.run(
            ['adb', 'mdns', 'services'],
            capture_output=True,
            text=True,
            check=True
        )

        devices_range_str = os.getenv('DEVICES_RANGE', "192.168.1.0/24")
        
        # Parse and filter the output
        raw_output = result.stdout.strip()
        lines = raw_output.split('\n')
        
        filtered_lines = []
        for line in lines:
            if not line.strip() or "_adb._tcp." not in line:
                continue

            # The IP address is the third field in the output
            parts = line.split()
            if len(parts) >= 3:
                # The IP can be in the format '192.168.1.10:5555'
                ip_part = parts[2]
                ip_match = re.match(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', ip_part)
                if ip_match:
                    ip = ip_match.group(1)
                    if is_ip_in_range(ip, devices_range_str):
                        filtered_lines.append(line)

        filtered_output = "\n".join(filtered_lines).strip()

        return jsonify({
            "status": "success",
            "output": filtered_output if filtered_output else "No Serives Found In Mdns",
            "details": f"Command exited with code {result.returncode}"
        })
    except subprocess.CalledProcessError as e:
        return jsonify({
            "status": "error",
            "output": e.stderr,
            "details": f"ADB command failed with exit code {e.returncode}"
        }), 500
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": "An unexpected error occurred.",
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
        # Extract IP from device_id, which might be in 'ip:port' format
        ip_match = re.match(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', device_id)
        if not ip_match:
            return jsonify({
                "status": "error",
                "output": "Invalid device ID format. Expected IP address.",
                "details": "Device ID does not appear to be a valid IP address."
            }), 400

        ip_address = ip_match.group(1)
        devices_range_str = os.getenv('DEVICES_RANGE', "192.168.1.0/24")

        # Validate the IP address against the allowed range
        if not is_ip_in_range(ip_address, devices_range_str):
            return jsonify({
                "status": "error",
                "output": f"Connection to {ip_address} is not allowed.",
                "details": "The device IP is outside the configured DEVICES_RANGE."
            }), 403

        # Execute adb connect command
        connect_result = subprocess.run(
            ['adb', 'connect', device_id],
            capture_output=True,
            text=True
        )

        # Get updated device list and filter it
        devices_result = subprocess.run(
            ['adb', 'devices'],
            capture_output=True,
            text=True
        )
        
        # This part is now handled by get_adb_devices, but for direct feedback we can filter here too
        raw_output = devices_result.stdout.strip()
        lines = raw_output.split('\n')
        device_lines = lines[1:]
        
        filtered_devices = []
        for line in device_lines:
            if not line.strip():
                continue
            
            # This logic is duplicated from get_adb_devices. Consider refactoring to a shared utility.
            current_device_id = line.split('\t')[0]
            match = re.match(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', current_device_id)
            if match:
                ip = match.group(1)
                if is_ip_in_range(ip, devices_range_str):
                    filtered_devices.append(line)
            else:
                filtered_devices.append(line)

        filtered_output = "List of devices attached\n" + "\n".join(filtered_devices)

        return jsonify({
            "status": "success",
            "output": f"Connect result:\n{connect_result.stdout}\n\nDevices list:\n{filtered_output}",
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
        # Get the list of currently connected devices
        devices_result = subprocess.run(
            ['adb', 'devices'],
            capture_output=True,
            text=True,
            check=True
        )

        raw_output = devices_result.stdout.strip()
        lines = raw_output.split('\n')
        device_lines = lines[1:]

        devices_range_str = os.getenv('DEVICES_RANGE', "192.168.1.0/24")
        
        disconnected_devices = []
        skipped_devices = []

        # Iterate over each device and decide whether to disconnect
        for line in device_lines:
            if not line.strip():
                continue
            
            device_id = line.split('\t')[0]
            ip_match = re.match(r'(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})', device_id)
            
            # We only disconnect devices that are within the allowed range.
            # This prevents this instance from interfering with devices managed by other instances.
            if ip_match:
                ip = ip_match.group(1)
                if is_ip_in_range(ip, devices_range_str):
                    subprocess.run(['adb', 'disconnect', device_id], capture_output=True, text=True)
                    disconnected_devices.append(device_id)
                else:
                    skipped_devices.append(device_id)
            else:
                # Assuming USB devices should not be disconnected by this logic.
                skipped_devices.append(f"{device_id} (USB device)")


        # Get final device list
        final_devices_result = subprocess.run(
            ['adb', 'devices'],
            capture_output=True,
            text=True
        )
        output_message = ""
        if disconnected_devices:
            output_message += "Disconnected Devices:"
            for x in disconnected_devices: output_message += f"\n- {x}"
        else: output_message += "No Devices To Disconnect..."

        skipped_devices = ""
        if skipped_devices:
            output_message += "\n\nSkipped Devices:"
            for x in skipped_devices: output_message += f"\n-{x}"
        else: output_message += "\n\nNo Devices Skipped..."

        output_message += "\n\n" + final_devices_result.stdout.strip()

        return jsonify({
            "status": "success",
            "output": output_message,
            "details": "Disconnect command executed for devices within the allowed range."
        })
    except subprocess.CalledProcessError as e:
        return jsonify({
            "status": "error",
            "output": e.stderr,
            "details": f"ADB command failed with exit code {e.returncode}"
        }), 500
    except Exception as e:
        return jsonify({
            "status": "error",
            "output": "An unexpected error occurred.",
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

        # Check if port 9786 is available, if not, kill the process using it
        if not is_port_available(9786):
            print("Port 9786 is not available, killing process using it...")
            kill_process_on_port(9786)
            time.sleep(2)  # Wait a bit for the port to be freed

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

        # Also stop any running tunnel that depends on ws-scrcpy
        tunnel_stopped = process_manager.stop_process('cloudflared')

        messages = []
        if stopped:
            messages.append("ws-scrcpy stopped successfully")
        else:
            messages.append("ws-scrcpy was not running")

        if tunnel_stopped:
            messages.append("Associated tunnel also stopped")
        # No message if tunnel wasn't running

        return jsonify({
            "status": "success",
            "output": "; ".join(messages),
            "details": "Process terminated"
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

    app.run(host='0.0.0.0', port=BACKEND_PORT, debug=True)