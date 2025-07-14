from flask import request, jsonify, Response
import subprocess
import os
import json
import time
from routes import main

@main.route('/run-script-services-stream', methods=['GET'])
def run_script_services_stream():
    # Retrieve query parameters
    action = request.args.get('action')
    app = request.args.get('app')
    env = request.args.get('env')
    
    # Run PowerShell script with arguments
    # using -command instead of -file, because with -file all parameters are treated as strings
    command = [
        'pwsh', '-NoProfile', '-Command',
        f"& {{ . 'D:\\gitlab\\cmi-administration-webapp\\pwsh\\cmi-stop-start-services.ps1' "
        f"-Action {action} -App {app} -Env {env} }}"
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

@main.route('/run-script-services-single-stream')
def run_script_services_single_stream():
    env = request.args.get('env')
    ps_command = [
        'pwsh', 
        '-NoProfile',
        '-File', os.path.join(os.getcwd(), 'pwsh', 'cmi-list-single-services.ps1').replace('\\', '\\\\'),
        '-Env', f"{env}",
    ]
    try:
        result = subprocess.run(ps_command, capture_output=True, text=True, encoding='utf-8', errors='replace')
        print("Return code:", result.returncode)
        print("STDOUT repr:", repr(result.stdout))
        print("STDERR repr:", repr(result.stderr))
        if result.returncode == 0:
            try:
                output = json.loads(result.stdout)
                # Direkt das Array zurückgeben
                return jsonify(output), 200
            except json.JSONDecodeError:
                return jsonify({"error": "Invalid JSON output from PowerShell script"}), 500
        else:
            return jsonify({"error": result.stderr.strip()}), 500
            
    except Exception as e:
        return jsonify({"error": str(e)}), 500
