"""Service control routes"""

from flask import request, jsonify
from routes import main
from utils import PowerShellRunner, PowerShellError, PowerShellTimeoutError


@main.route('/service-control', methods=['POST'])
def service_control():
    """Control Windows services (start/stop) on remote hosts
    
    Expected JSON payload:
        {
            "service": "service_name",
            "action": "start|stop",
            "hostname": "target_hostname"
        }
    
    Returns:
        JSON with service status or error message
    """
    data = request.get_json()
    service = data.get("service")
    action = data.get("action")
    hostname = data.get("hostname")

    # Validate input
    if not service or not action or not hostname:
        return jsonify({"error": "Missing parameters: service, action, or hostname"}), 400
    
    if action not in ["start", "stop"]:
        return jsonify({"error": "Invalid action. Must be 'start' or 'stop'"}), 400

    # Execute PowerShell script
    try:
        runner = PowerShellRunner('service_control', timeout=35)
        result = runner.run({
            'Service': service,
            'Action': action,
            'Hostname': hostname
        })
        
        # Parse the result
        output_lines = result.splitlines()
        last_line = output_lines[-1] if output_lines else ""
        
        return jsonify({"status": last_line}), 200
        
    except PowerShellTimeoutError as e:
        return jsonify({"error": str(e)}), 504
    except PowerShellError as e:
        return jsonify({"error": str(e)}), 500
    except Exception as e:
        return jsonify({"error": f"Unexpected error: {str(e)}"}), 500
