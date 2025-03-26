from flask import request, jsonify, send_file
import subprocess
import os
import json
import base64
import gzip
import io
import zipfile
from . import main


@main.route('/run-script-cockpit-overview', methods=['POST'])
def run_script_cockpit_overview():
    try:
        data = request.get_json()
        app = data.get('app')
        env = data.get('env')
        command = [
            'pwsh', '-NoProfile',
            '-File', os.path.join(os.getcwd(), 'pwsh', 'cmi-cockpit.ps1').replace('\\', '\\\\'),
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

@main.route('/get-log-files', methods=['GET'])
def get_log_files():
    try:
        log_date = request.args.get("log_date")
        env = request.args.get("env")

        if not log_date or not env:
            return jsonify({"error": "Missing required parameters: log_date or env"}), 400

        # Construct the PowerShell command
        command = [
            'pwsh', '-NoProfile',
            '-File', os.path.join(os.getcwd(), 'pwsh', 'cmi-download-log-files.ps1').replace('\\', '\\\\'),
            '-Date', log_date,
            '-Env', env
        ]

        # Run the PowerShell script
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        print("Raw PowerShell Output:", result.stdout)  # Log the output for debugging

        # Decode and decompress the PowerShell output
        compressed_json = base64.b64decode(result.stdout.strip())
        decompressed_json = gzip.decompress(compressed_json).decode('utf-8')

        # Parse the JSON
        files = json.loads(decompressed_json)

    except subprocess.CalledProcessError as e:
        print("PowerShell Error Output:", e.stderr)  # Log error output
        return jsonify({"error": f"PowerShell script failed: {e.stderr}"}), 500
    except Exception as e:
        print("Decompression/Decoding Error:", str(e))  # Log detailed error
        return jsonify({"error": f"Failed to process JSON: {str(e)}"}), 500

    if not files:
        return jsonify({"error": "No files found for the specified date and environment."}), 404

    # Create a ZIP file in memory
    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zip_file:
        for file in files:
            file_name = file["NewName"]
            file_content = base64.b64decode(file["Content"])
            zip_file.writestr(file_name, file_content)

    zip_buffer.seek(0)  # Reset buffer pointer

    # Return the ZIP file as a downloadable response
    return send_file(
        zip_buffer,
        as_attachment=True,
        download_name=f"logs_{log_date}_{env}.zip",
        mimetype="application/zip"
    )

@main.route('/get-config-files', methods=['GET'])
def get_config_files():
    try:
        # Construct the PowerShell command
        command = [
            'pwsh', 
            '-NoProfile',
            '-File', os.path.join(os.getcwd(), 'pwsh', 'cmi-download-config-files.ps1').replace('\\', '\\\\')
        ]

        # Run the PowerShell script
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        print("Raw PowerShell Output:", result.stdout)  # Log the output for debugging

        # Decode the Base64 output to get the ZIP file bytes
        zip_bytes = base64.b64decode(result.stdout.strip())

    except subprocess.CalledProcessError as e:
        print("PowerShell Error Output:", e.stderr)  # Log error output
        return jsonify({"error": f"PowerShell script failed: {e.stderr}"}), 500
    except Exception as e:
        print("Decoding Error:", str(e))  # Log detailed error
        return jsonify({"error": f"Failed to process output: {str(e)}"}), 500

    # Return the ZIP file as a downloadable response
    return send_file(
        io.BytesIO(zip_bytes),
        as_attachment=True,
        download_name="cmi-config-files.zip",
        mimetype="application/zip"
    )
