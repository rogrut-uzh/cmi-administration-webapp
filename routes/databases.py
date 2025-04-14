from flask import request, jsonify
import subprocess
import os
from routes import main

@main.route('/database-backup')
def database_backup():
    db = request.args.get('db')
    dbhost = request.args.get('dbhost')
    ps_command = [
        'pwsh', 
        '-NoProfile',
        '-File', os.path.join(os.getcwd(), 'pwsh', 'cmi-databases.ps1'),
        '-Job', 'backup',
        '-Db', db,
        '-DbHost', dbhost
    ]
    try:
        result = subprocess.run(ps_command, capture_output=True, text=True, encoding='utf-8', errors='replace')
        print("Return code:", result.returncode)
        print("STDOUT repr:", repr(result.stdout))
        print("STDERR repr:", repr(result.stderr))

        output = result.stdout.strip()

        if result.returncode == 0 and "SUCCESS" in output:
            return jsonify({"message": "Backup erfolgreich!"}), 200
        else:
            return jsonify({"error": output or "Backup fehlgeschlagen"}), 500

    except Exception as e:
        return jsonify({"error": str(e)}), 500
