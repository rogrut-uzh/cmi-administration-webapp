from flask import request, jsonify
import subprocess
import os
import json
from . import main
from .auth import requires_auth

@main.route('/run-script-metatool', methods=['POST'])
@requires_auth
def run_script_metatool():
    try:
        # Retrieve query parameters
        data = request.get_json()
        app = data.get('app')
        env = data.get('env')
        command = [
            'pwsh', '-NoProfile', 
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

@main.route('/update-metatool', methods=['POST'])
@requires_auth
def update_remote_file():
    data = request.get_json()
    server = data.get("server")  # z. B. item.app.host
    file_path = data.get("file")
    content = data.get("content")

    if not server or not file_path or content is None:
        return jsonify({"error": "Missing required parameters."}), 400

    ps_command = (
        f"Invoke-Command -ComputerName {server} -ScriptBlock {{ "
        f"Set-Content -Path '{file_path}' -Value @'\n{content}\n'@ -Encoding UTF8 }}"
    )

    command = ['pwsh', '-NoProfile', '-Command', ps_command]
    
    try:
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode == 0:
            return jsonify({"Status": "Success"}), 200
        else:
            return jsonify({"error": result.stderr.strip()}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@main.route('/get-file', methods=['GET'])
@requires_auth
def get_file():
    file_path = request.args.get("file")
    server = request.args.get("server")
    if not file_path or not server:
        return jsonify({"error": "Missing required parameters: file and server."}), 400

    # PowerShell-Befehl: Ruft den Dateiinhalte (als Rohstring) vom Remote-Server ab.
    ps_command = (
        f"Invoke-Command -ComputerName {server} -ScriptBlock {{ "
        f"Get-Content -Path '{file_path}' -Raw }}"
    )
    command = ['pwsh', '-NoProfile', '-Command', ps_command]
    try:
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode == 0:
            return jsonify({"content": result.stdout})
        else:
            return jsonify({"error": result.stderr.strip()}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500
