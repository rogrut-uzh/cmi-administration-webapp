from flask import Flask, render_template, request, Response, jsonify
from functools import wraps
import subprocess
import os
import time
import json
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

@app.route('/services')
@requires_auth
def services():
    return render_template('services.html', active_page='services')

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

@app.route('/run-script-cockpit-overview', methods=['POST'])
def run_script_cockpit_overview():
    try:
        # Retrieve query parameters
        data = request.get_json()
        app = data.get('app')
        env = data.get('env')
        
#        command = [
#            'pwsh', '-NoProfile', '-Command',
#            f"$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new(); "
#            f"$password = ConvertTo-SecureString '{p}' -AsPlainText -Force; "
#            f"$cred = New-Object System.Management.Automation.PSCredential('{u}', $password); "
#            f"& {{ . 'D:\\gitlab\\cmi-administration-webapp\\pwsh\\cmi-cockpit.ps1' "
#            f"-App {app} -Env {env} }}"
#        ]
    
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

@app.route('/get-log-files', methods=['POST'])
def get_log_files():
    try:
        # Retrieve data from the POST request
        data = request.get_json()
        log_date = data.get('log_date')
        env = data.get('env')

        if not log_date or not env:
            return jsonify({"error": "Missing required parameters: log_date or env"}), 400

        # Construct the PowerShell command
        command = [
            'pwsh', '-NoProfile', '-File', 'D:\\gitlab\\cmi-administration-webapp\\pwsh\\cmi-download-log-files.ps1',
            '-Date', f"{log_date}",
            '-Env', f"{env}"
        ]

        # Run the PowerShell script
        result = subprocess.run(command, capture_output=True, text=True)
        
        #debug_info = {
        #    "return_code": result.returncode,
        #    "stdout": result.stdout.strip(),
        #    "stderr": result.stderr.strip(),
        #}
        
        # Return debug information along with the normal response
        if result.returncode == 0:
            return jsonify({"message": result.stdout.strip()}), 200
            #return jsonify({"message": result.stdout.strip(), "debug": debug_info}), 200
        else:
            return jsonify({"error": result.stderr.strip()}), 500
            #return jsonify({"error": result.stderr.strip(), "debug": debug_info}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Run the Flask application
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False) # <------- change debug mode if nescessary -----------
