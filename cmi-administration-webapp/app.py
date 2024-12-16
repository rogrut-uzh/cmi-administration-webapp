from flask import Flask, render_template, request, Response
import subprocess
import os
import time

# Initialize the Flask application
app = Flask(__name__)

# Retrieve environment variables
username = os.environ.get("CMI_WEBAPP_USER")
password = os.environ.get("CMI_WEBAPP_PW")

@app.route('/')
def index():
    # Serve the HTML page
    return render_template('index.html')

@app.route('/run-script-stream', methods=['POST'])
def run_script_stream():
    # Parse JSON payload
    data = request.get_json()
    action = data.get('action')
    app_name = data.get('app')
    env = data.get('env')
    include_relay = data.get('includeRelay', True)  # Default to True if not provided        
    # Convert includeRelay to PowerShell $true or $false
    include_relay_ps = "$true" if include_relay else "$false"
    
    # Run PowerShell script with arguments
    command = [
        'powershell', '-Command',
        f"$password = ConvertTo-SecureString '{password}' -AsPlainText -Force; "
        f"$cred = New-Object System.Management.Automation.PSCredential('{username}', $password); "
        f"& {{ . 'D:\\gitlab\\zidbacons02\\cmi-administration-webapp\\pwsh\\cmi-stop-start-services-webapp.ps1' -Action {action} -App {app_name} -Env {env} -IncludeRelay {include_relay_ps}; exit $LASTEXITCODE }}"
    ]

    def generate_output():
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        while True:
            output = process.stdout.readline()
            if output == '' and process.poll() is not None:
                break
            if output:
                yield f"data: {output.strip()}\n\n"
            time.sleep(0.5)  # Avoid overwhelming the client

        # Send any remaining errors
        stderr = process.stderr.read()
        if stderr:
            yield f"data: ERROR: {stderr.strip()}\n\n"

    return Response(generate_output(), content_type='text/event-stream')

# Run the Flask application
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
