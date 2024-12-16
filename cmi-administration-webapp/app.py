from flask import Flask, render_template, request, jsonify
import subprocess
import os

# Initialize the Flask application
app = Flask(__name__)

# Retrieve environment variables
username = os.environ.get("CMI_WEBAPP_USER")
password = os.environ.get("CMI_WEBAPP_PW")

@app.route('/')
def index():
    # Serve the HTML page
    return render_template('index.html')

@app.route('/run-script', methods=['POST'])
def run_script():
    # Parse JSON payload
    data = request.get_json()
    action = data.get('action')
    app_name = data.get('app')
    env = data.get('env')

    if not action or not app_name or not env:
        return jsonify({"error": "Missing parameters"}), 400

    try:
        # Run PowerShell script with arguments
        result = subprocess.run(
            [
                'powershell', '-Command',
                f"$password = ConvertTo-SecureString '{password}' -AsPlainText -Force; "
                f"$cred = New-Object System.Management.Automation.PSCredential('{username}', $password); "
                f"& {{ . 'D:\\gitlab\\zidbacons02\\cmi-administration-webapp\\pwsh\\cmi-stop-start-services-webapp-fortesting.ps1' -Action {action} -App {app_name} -Env {env}; exit $LASTEXITCODE }}"
            ],
            capture_output=True, text=True
        )

        # Log outputs for debugging
        #print(f"STDOUT: {result.stdout}")
        #print(f"STDERR: {result.stderr}")
        #print(f"Return Code: {result.returncode}")

        # Check if script ran successfully
        if result.returncode == 0:
            return result.stdout, 200
            #return jsonify({"output": result.stdout.strip()}), 200
        else:
            return result.stderr, 500
            #return jsonify({"error": result.stderr.strip()}), 500

    except Exception as e:
        # Handle unexpected exceptions
        print(f"Exception: {e}")
        return jsonify({"error": str(e)}), 500

# Run the Flask application
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=false)
