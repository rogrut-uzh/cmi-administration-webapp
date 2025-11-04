"""Cockpit routes for log and config file downloads"""

from flask import request, jsonify, send_file
import io
import zipfile
import base64
from routes import main
from utils import PowerShellRunner, PowerShellError, PowerShellTimeoutError


@main.route('/get-log-files', methods=['GET'])
def get_log_files():
    """Download log files for a specific date and environment
    
    Query parameters:
        log_date: Date in format yyyymmdd
        env: Environment (test or prod)
    
    Returns:
        ZIP file containing log files
    """
    log_date = request.args.get("log_date")
    env = request.args.get("env")

    if not log_date or not env:
        return jsonify({"error": "Missing required parameters: log_date or env"}), 400

    try:
        # Run PowerShell script and parse JSON output
        runner = PowerShellRunner('download_logs')
        files = runner.run_json(
            {'Date': log_date, 'Env': env},
            decode_base64=True,
            decompress_gzip=True
        )

    except PowerShellError as e:
        return jsonify({"error": str(e)}), 500
    except Exception as e:
        return jsonify({"error": f"Failed to process files: {str(e)}"}), 500

    if not files:
        return jsonify({"error": "No files found for the specified date and environment."}), 404

    # Create ZIP file in memory
    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, "w", zipfile.ZIP_DEFLATED) as zip_file:
        for file in files:
            file_name = file["NewName"]
            file_content = base64.b64decode(file["Content"])
            zip_file.writestr(file_name, file_content)

    zip_buffer.seek(0)

    # Return ZIP file
    return send_file(
        zip_buffer,
        as_attachment=True,
        download_name=f"logs_{log_date}_{env}.zip",
        mimetype="application/zip"
    )


@main.route('/get-config-files', methods=['GET'])
def get_config_files():
    """Download all CMI config files (MetaTool.ini)
    
    Returns:
        ZIP file containing config files from all mandants
    """
    try:
        # Run PowerShell script and get base64 ZIP
        runner = PowerShellRunner('download_config')
        result = runner.run()
        
        # Decode base64 to get ZIP bytes
        zip_bytes = base64.b64decode(result)

    except PowerShellError as e:
        return jsonify({"error": str(e)}), 500
    except Exception as e:
        return jsonify({"error": f"Failed to process output: {str(e)}"}), 500

    # Return ZIP file
    return send_file(
        io.BytesIO(zip_bytes),
        as_attachment=True,
        download_name="cmi-config-files.zip",
        mimetype="application/zip"
    )