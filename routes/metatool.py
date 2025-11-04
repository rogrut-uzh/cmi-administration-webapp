"""MetaTool configuration file routes"""

from flask import request, jsonify
import subprocess
from routes import main
from .auth import requires_auth


@main.route('/update-metatool', methods=['POST'])
@requires_auth
def update_remote_file():
    """Update MetaTool.ini file on remote server
    
    Expected JSON payload:
        {
            "server": "hostname",
            "file": "full_file_path",
            "content": "file_content"
        }
    
    Returns:
        JSON with success/error message
    """
    data = request.get_json()
    server = data.get("server")
    file_path = data.get("file")
    content = data.get("content")

    if not server or not file_path or content is None:
        return jsonify({"error": "Missing required parameters."}), 400

    # Direct PowerShell command for file update
    ps_command = (
        f"Invoke-Command -ComputerName {server} -ScriptBlock {{ "
        f"Set-Content -Path '{file_path}' -Value @'\n{content}\n'@ -Encoding UTF8 }}"
    )

    command = ['pwsh', '-NoProfile', '-Command', ps_command]
    
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            return jsonify({"Status": "Success"}), 200
        else:
            return jsonify({"error": result.stderr.strip()}), 500
    except subprocess.TimeoutExpired:
        return jsonify({"error": "PowerShell command timed out"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@main.route('/get-file', methods=['GET'])
@requires_auth
def get_file():
    """Get file content from remote server
    
    Query parameters:
        file: Full file path
        server: Hostname
    
    Returns:
        JSON with file content or error message
    """
    file_path = request.args.get("file")
    server = request.args.get("server")
    
    if not file_path or not server:
        return jsonify({"error": "Missing required parameters: file and server."}), 400

    # Direct PowerShell command to get file content
    ps_command = (
        f"Invoke-Command -ComputerName {server} -ScriptBlock {{ "
        f"Get-Content -Path '{file_path}' -Raw }}"
    )
    
    command = ['pwsh', '-NoProfile', '-Command', ps_command]
    
    try:
        result = subprocess.run(command, capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            return jsonify({"content": result.stdout})
        else:
            return jsonify({"error": result.stderr.strip()}), 500
    except subprocess.TimeoutExpired:
        return jsonify({"error": "PowerShell command timed out"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500