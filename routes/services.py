from flask import request, jsonify, Response
import subprocess
import os
import json
import time
from routes import main

@main.route('/service-control', methods=['POST'])
def service_control():
    data = request.get_json()
    service = data.get("service")
    action = data.get("action")
    hostname = data.get("hostname")

    if not service or not action or not hostname:
        return jsonify({"error": "Missing parameters"}), 400

    command = [
        'pwsh',
        '-NoProfile',
        '-File', os.path.join(os.getcwd(), 'pwsh', 'cmi-control-single-service.ps1').replace('\\', '\\\\'),
        '-Service', service,
        '-Action', action,
        '-Hostname', hostname
    ]

    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            encoding='utf-8',
            timeout=35  # etwas länger als der PS-Timeout
        )

        output = result.stdout.strip().splitlines()
        last_line = output[-1] if output else ""

        if result.returncode == 0:
            return jsonify({"status": last_line}), 200
        elif result.returncode == 2 and last_line == "timeout":
            return jsonify({"error": "Service did not reach desired status within 30 seconds"}), 504
        else:
            return jsonify({"error": result.stderr.strip()}), 500

    except subprocess.TimeoutExpired:
        return jsonify({"error": "PowerShell script execution timed out"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500
