from flask import request, jsonify, Response
import subprocess
import os
import json
import time
from routes import main

@main.route('/run-script-db-stream')
def run_script_db_stream():
    job = request.args.get('job') # set in databases.js
    env = request.args.get('env') # set in databases.js
    ps_command = [
        'pwsh', 
        '-NoProfile',
        '-File', os.path.join(os.getcwd(), 'pwsh', 'cmi-databases.ps1').replace('\\', '\\\\'),
        '-Job', f"{job}",
        '-Env', f"{env}"
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


@main.route('/database-backup')
def database_backup():
    database = request.args.get('db')
    dbhost = request.args.get('dbhost')
    
    if not database or not dbhost:
        return jsonify({"error": "Missing database or dbhost parameter"}), 400
    
    ps_command = [
        'pwsh',
        '-NoProfile',
        '-File', os.path.join(os.getcwd(), 'pwsh', 'cmi-databases.ps1').replace('\\', '\\\\'),
        '-Job', 'backup',
        '-Database', database,
        '-DbHost', dbhost
    ]
    
    try:
        result = subprocess.run(ps_command, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=300)
        print("Backup Return code:", result.returncode)
        print("Backup STDOUT:", result.stdout)
        print("Backup STDERR:", result.stderr)
        
        if result.returncode == 0:
            return jsonify({"message": "SUCCESS"}), 200
        else:
            return jsonify({"error": result.stderr.strip() or result.stdout.strip()}), 500
    except subprocess.TimeoutExpired:
        return jsonify({"error": "Backup operation timed out (>5 minutes)"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500
