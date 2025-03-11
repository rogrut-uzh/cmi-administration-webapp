from flask import Flask, render_template, request, Response, jsonify, send_file
from functools import wraps
import io
import gzip
import zipfile
import subprocess
import os
import time
import json
import base64
import logging
logging.basicConfig(level=logging.DEBUG)
#import logging
#logging.basicConfig(filename='app_debug.log', level=logging.DEBUG)

# Initialize the Flask application
app = Flask(__name__)

# Retrieve environment variables
#u = os.environ.get("CMI_WEBAPP_USER")
#p = os.environ.get("CMI_WEBAPP_PW")


# HTTP BASIC AUTHENTICATION
# Function to verify the username and password
def check_auth(a, b):
    """Validate if a username/password combination is valid."""
    basicauthuser = os.environ.get("CMI_WEBAPP_BASICAUTH_USER")
    basicauthpassword = os.environ.get("CMI_WEBAPP_BASICAUTH_PW")
    return a == basicauthuser and b == basicauthpassword
    #return a == "a" and b == "b"

# Function to send a 401 Unauthorized response
def authenticate():
    """Send a 401 response that enables basic auth."""
    return Response(
        'Could not verify your access level.\n'
        'You have to login with proper credentials.', 401,
        {'WWW-Authenticate': 'Basic realm="Login Required"'})

def requires_auth(f):
    @wraps(f)  # Ensure the function keeps its name and docstring
    def decorated(*args, **kwargs):
        auth = request.authorization
        if not auth or not check_auth(auth.username, auth.password):
            return authenticate()
        return f(*args, **kwargs)
    return decorated

@app.route('/')
@requires_auth
def cockpit():
    return render_template('cockpit.html', active_page='cockpit')

@app.route('/fulloverview')
@requires_auth
def fulloverview():
    return render_template('fulloverview.html', active_page='fulloverview')

@app.route('/services')
@requires_auth
def services():
    return render_template('services.html', active_page='services')

@app.route('/metatool')
@requires_auth
def metatool():
    return render_template('metatool.html', active_page='metatool')

@app.route('/run-script-cockpit-overview', methods=['POST'])
def run_script_cockpit_overview():
    try:
        # Retrieve query parameters
        data = request.get_json()
        app = data.get('app')
        env = data.get('env')    
        command = [
            'pwsh', '-NoProfile', '-File', 'D:\\gitlab\\cmi-administration-webapp\\pwsh\\cmi-cockpit.ps1',
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

@app.route('/get-log-files', methods=['GET'])
def get_log_files():
    try:
        log_date = request.args.get("log_date")
        env = request.args.get("env")

        if not log_date or not env:
            return jsonify({"error": "Missing required parameters: log_date or env"}), 400

        # Construct the PowerShell command
        command = [
            'pwsh', '-NoProfile', '-File', 'D:\\gitlab\\cmi-administration-webapp\\pwsh\\cmi-download-log-files.ps1',
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

@app.route('/get-config-files', methods=['GET'])
def get_config_files():
    try:
        # Construct the PowerShell command
        command = [
            'pwsh', '-NoProfile', '-File', 'D:\\gitlab\\cmi-administration-webapp\\pwsh\\cmi-download-config-files.ps1',
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

@app.route('/run-script-fulloverview', methods=['POST'])
def run_script_fulloverview():
    try:
        # Retrieve query parameters
        data = request.get_json()
        app = data.get('app')
        env = data.get('env')
        command = [
            'pwsh', '-NoProfile', '-File', 'D:\\gitlab\\cmi-administration-webapp\\pwsh\\cmi-cockpit.ps1',
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

@app.route('/run-script-services-stream', methods=['GET'])
def run_script_services_stream():
    # Retrieve query parameters
    action = request.args.get('action')
    app = request.args.get('app')
    env = request.args.get('env')
    include_relay = request.args.get('includeRelay', 'true') == 'true'
    include_relay_ps = "$true" if include_relay else "$false"
    
    # Run PowerShell script with arguments
    # using -command instead of -file, because with -file all parameters are treated as strings, but -IncludeRelay must be boolean.
    command = [
        'pwsh', '-NoProfile', '-Command',
        f"& {{ . 'D:\\gitlab\\cmi-administration-webapp\\pwsh\\cmi-stop-start-services-webapp.ps1' "
        f"-Action {action} -App {app} -Env {env} -IncludeRelay {include_relay_ps} }}"
    ]

    def generate_output():
        try:
            process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8')
            while True:
                output = process.stdout.readline()
                if output == '' and process.poll() is not None:
                    break
                if output:
                    yield f"data: {output.strip()}\n\n"
                time.sleep(0.1)  # Avoid overwhelming the client

            # Send any remaining errors
            stderr = process.stderr.read()
            if stderr:
                yield f"data: ERROR: {stderr.strip()}\n\n"
        except Exception as e:
            yield f"data: ERROR: {str(e)}\n\n"

    return Response(generate_output(), content_type='text/event-stream')

@app.route('/services-single')
def run_script_services_single_stream():
    endpoints = [
        {"label": "CMI Prod", "url": "https://zidbacons02.d.uzh.ch/api/data/cmi/prod"},
        {"label": "AIS Prod", "url": "https://zidbacons02.d.uzh.ch/api/data/ais/prod"},
        {"label": "CMI Test", "url": "https://zidbacons02.d.uzh.ch/api/data/cmi/test"},
        {"label": "AIS Test", "url": "https://zidbacons02.d.uzh.ch/api/data/ais/test"}
    ]
    
    endpoints_data = []
    
    for endpoint in endpoints:
        label = endpoint["label"]
        url = endpoint["url"]
        entries = []
        try:
            # Falls Zertifikatfehler auftreten: verify=False verwenden (Achtung: nur zu Debug-Zwecken!)
            resp = requests.get(url, timeout=10)  # , verify=False
            resp.raise_for_status()
            json_data = resp.json()
            logging.debug(f"API Response from {url}: {json_data}")
            
            # Falls die API kein Array liefert, packe das Ergebnis in eine Liste
            if not isinstance(json_data, list):
                json_data = [json_data]
            
            for item in json_data:
                # Debug-Ausgabe, um den Aufbau zu prüfen:
                logging.debug(f"Item: {item}")
                app_info = item.get('result', {}).get('app', {})
                hostname = app_info.get('hostname', 'Unknown')
                servicename = app_info.get('servicename', '')
                servicenamerelay = app_info.get('servicenamerelay', '')
                entries.append({
                    "hostname": hostname,
                    "servicename": servicename,
                    "servicenamerelay": servicenamerelay,
                    "status_service": None,
                    "status_relay": None
                })
        except Exception as e:
            logging.error(f"Fehler beim Abruf von {url}: {e}")
            entries.append({
                "hostname": f"Error: {e}",
                "servicename": "",
                "servicenamerelay": "",
                "status_service": f"Error: {e}",
                "status_relay": f"Error: {e}"
            })
        
        endpoints_data.append({
            "label": label,
            "endpoint": url,
            "entries": entries
        })
    
    # Sammle pro Host alle eindeutigen Service-Namen
    host_services = {}
    for endpoint in endpoints_data:
        for entry in endpoint["entries"]:
            hostname = entry["hostname"]
            # Überspringe Einträge, die bereits einen Fehler enthalten
            if hostname.startswith("Error"):
                continue
            if hostname not in host_services:
                host_services[hostname] = set()
            if entry["servicename"]:
                host_services[hostname].add(entry["servicename"])
            if entry["servicenamerelay"]:
                host_services[hostname].add(entry["servicenamerelay"])
    
    # Für jeden Host: Einmaliger Powershell-Aufruf
    host_statuses = {}
    for hostname, services_set in host_services.items():
        services_str = ",".join(services_set)
        logging.debug(f"Für Host '{hostname}' werden die Services abgefragt: {services_str}")
        try:
            ps_command = [
                "pwsh", '-NoProfile', "-File", "D:\\gitlab\\cmi-administration-webapp\\pwsh\\cmi-stop-start-services-webapp-single.ps1",
                "-Computername", hostname,
                "-Services", services_str
            ]
            ps_result = subprocess.run(ps_command, capture_output=True, text=True, timeout=30)
            logging.debug(f"Powershell Rückgabe für '{hostname}': returncode={ps_result.returncode}, stdout={ps_result.stdout}, stderr={ps_result.stderr}")
            if ps_result.returncode == 0:
                host_status = json.loads(ps_result.stdout.strip())
            else:
                host_status = {}
                logging.error(f"Powershell Fehlercode {ps_result.returncode} für Host '{hostname}'")
        except Exception as e:
            logging.error(f"Powershell Exception für Host '{hostname}': {e}")
            host_status = {}
        host_statuses[hostname] = host_status

    # Aktualisiere alle Einträge mit den abgefragten Statuswerten
    for endpoint in endpoints_data:
        for entry in endpoint["entries"]:
            hostname = entry["hostname"]
            if hostname in host_statuses:
                mapping = host_statuses[hostname]
                entry["status_service"] = mapping.get(entry["servicename"], "unknown")
                entry["status_relay"] = mapping.get(entry["servicenamerelay"], "unknown")
            else:
                entry["status_service"] = "Error"
                entry["status_relay"] = "Error"
    
    return render_template("services-single.html", endpoints_data=endpoints_data)

@app.route('/run-script-metatool', methods=['POST'])
def run_script_metatool():
    try:
        # Retrieve query parameters
        data = request.get_json()
        app = data.get('app')
        env = data.get('env')
        command = [
            'pwsh', '-NoProfile', '-File', 'D:\\gitlab\\cmi-administration-webapp\\pwsh\\cmi-cockpit.ps1',
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

@app.route('/update-metatool', methods=['POST'])
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

@app.route('/get-file', methods=['GET'])
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


# Run the Flask application
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True) # <------- change debug mode if nescessary -----------
