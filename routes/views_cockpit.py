from flask import request, jsonify, send_file
import subprocess
import os
import json
import base64
import gzip
import io
import zipfile
from routes import main


@main.route('/run-script-cockpit-overview', methods=['POST'])
def run_script_cockpit_overview():
    try:
        data = request.get_json()
        app = data.get('app')
        env = data.get('env')
        command = [
            'pwsh', '-NoProfile',
            '-File', os.path.join(os.getcwd(), 'pwsh', 'cmi-cockpit_new202508.ps1').replace('\\', '\\\\'),
            '-App', f"{app}",
            '-Env', f"{env}"
        ]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode == 0:
            try:
                output = json.loads(result.stdout)
                return jsonify({"Status": "Success", "Data": output}), 200
            except json.JSONDecodeError:
                return jsonify({"error": "Invalid JSON output from PowerShell script"}), 500
        else:
            return jsonify({"error": result.stderr.strip()}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500
