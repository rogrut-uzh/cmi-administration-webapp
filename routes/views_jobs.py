from flask import request, jsonify
import subprocess
import os
import json
from routes import main

@main.route('/run-script-fulloverview-jobs', methods=['POST'])
def run_script_fulloverview():
    try:
        # Retrieve query parameters
        data = request.get_json()
        command = [
            'pwsh', 
            '-NoProfile',
            '-File', os.path.join(os.getcwd(), 'pwsh', 'cmi-cockpit_new202508.ps1').replace('\\', '\\\\'),
        ]
        # Run the PowerShell script
        result = subprocess.run(command, capture_output=True, text=True)

        if result.returncode == 0:
            # Attempt to parse PowerShell output as JSON
            try:
                output = json.loads(result.stdout)
                return jsonify({"Status": "Success", "Data": output}), 200
            except json.JSONDecodeError:
                return jsonify({"error": "Invalid JSON output from PowerShell script"}), 500
        else:
            return jsonify({"error": result.stderr.strip()}), 500

    except Exception as e:
        return jsonify({"error": str(e)}), 500
