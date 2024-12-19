from flask import Flask, render_template, request, Response, jsonify
import subprocess
import os
import time
import json

# Initialize the Flask application
app = Flask(__name__)

# Retrieve environment variables
username = os.environ.get("CMI_WEBAPP_USER")
password = os.environ.get("CMI_WEBAPP_PW")

@app.route('/')
def cockpit():
    return render_template('cockpit.html', active_page='cockpit')

@app.route('/services')
def services():
    return render_template('services.html', active_page='services')

@app.route('/run-script-services-stream', methods=['GET'])
def run_script_services_stream():
    # Retrieve query parameters
    action = request.args.get('action')
    app = request.args.get('app')
    env = request.args.get('env')
    include_relay = request.args.get('includeRelay', 'true') == 'true'
    # Convert includeRelay to PowerShell $true or $false
    include_relay_ps = "$true" if include_relay else "$false"
    
    # Run PowerShell script with arguments
    command_stop_start_services = [
        'pwsh', '-NoProfile', '-Command',
        f"$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new(); "
        f"$password = ConvertTo-SecureString '{password}' -AsPlainText -Force; "
        f"$cred = New-Object System.Management.Automation.PSCredential('{username}', $password); "
        f"& {{ . 'D:\\gitlab\\zidbacons02\\cmi-administration-webapp\\pwsh\\cmi-stop-start-services-webapp.ps1' "
        f"-Action {action} -App {app} -Env {env} -IncludeRelay {include_relay_ps}; exit $LASTEXITCODE }}"
    ]

    def generate_output():
        try:
            process = subprocess.Popen(command_stop_start_services, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8')
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

@app.route('/run-script-cockpit-overview', methods=['POST'])
def run_script_cockpit_overview():
    try:
        # Retrieve query parameters
        data = request.get_json()
        app = data.get('app')
        env = data.get('env')
        
        command = [
            'pwsh', '-NoProfile', '-Command',
            f"$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new(); "
            f"$password = ConvertTo-SecureString '{password}' -AsPlainText -Force; "
            f"$cred = New-Object System.Management.Automation.PSCredential('{username}', $password); "
            f"& {{ . 'D:\\gitlab\\zidbacons02\\cmi-administration-webapp\\pwsh\\cmi-cockpit.ps1' "
            f"-App {app} -Env {env} }}"
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

# Run the Flask application
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
