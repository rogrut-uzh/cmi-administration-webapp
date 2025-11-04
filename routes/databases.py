"""Database backup routes"""

from flask import request, jsonify
from routes import main
from utils import PowerShellRunner, PowerShellError, PowerShellTimeoutError


@main.route('/database-backup')
def database_backup():
    """Trigger database backup
    
    Query parameters:
        db: Database name
        dbhost: Database host
    
    Returns:
        JSON with success/error message
    """
    db = request.args.get('db')
    dbhost = request.args.get('dbhost')
    
    if not db or not dbhost:
        return jsonify({"error": "Missing parameters: db or dbhost"}), 400

    try:
        runner = PowerShellRunner('database_backup', timeout=120)
        result = runner.run({
            'Job': 'backup',
            'Db': db,
            'DbHost': dbhost
        })
        
        if "SUCCESS" in result:
            return jsonify({"message": "Backup successful"}), 200
        else:
            return jsonify({"error": result or "Backup failed"}), 500
            
    except PowerShellTimeoutError as e:
        return jsonify({"error": str(e)}), 504
    except PowerShellError as e:
        return jsonify({"error": str(e)}), 500
    except Exception as e:
        return jsonify({"error": f"Unexpected error: {str(e)}"}), 500