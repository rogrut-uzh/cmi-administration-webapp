from flask import request, jsonify
import subprocess, os, json, io
from . import main

@main.route('/run-script-fulloverview', methods=['POST'])
def run_script_fulloverview():
    try:
        # Retrieve query parameters
        data = request.get_json()
        app = data.get('app')
        env = data.get('env')
        command = [
            'pwsh', 
            '-NoProfile',
            '-File', os.path.join(os.getcwd(), 'pwsh', 'cmi-cockpit.ps1').replace('\\', '\\\\'),
            '-App', f"{app}",
            '-Env', f"{env}"
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
