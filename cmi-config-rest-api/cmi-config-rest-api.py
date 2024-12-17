from flask import Flask, jsonify, request
import xml.etree.ElementTree as ET

app = Flask(__name__)
xml_data_path = r'D:\gitlab\cmi-config\cmi-config.xml'
api_port = 5001

def load_xml_data(file_path):
    tree = ET.parse(file_path)
    root = tree.getroot()
    data = []
    for mandant in root.findall('mandant'):
        mandant_data = {'id': mandant.get('id')}
        for env in ['prod', 'test']:
            env_data = mandant.find(env)
            if env_data is not None:
                env_info = {}
                for child in env_data:
                    if child.tag == 'namefull':
                        env_info['namefull'] = child.text.strip() if child.text else None
                    elif child.tag == 'app':
                        releaseversion = child.find('releaseversion')
                        host = child.find('host')
                        env_info['app/releaseversion'] = releaseversion.text.strip() if releaseversion is not None else None
                        env_info['app/host'] = host.text.strip() if host is not None else ''
                    elif child.tag == 'database':
                        host = child.find('host')
                        env_info['database/host'] = host.text.strip() if host is not None else None
                mandant_data[env] = env_info
        data.append(mandant_data)
    return data

def filter_data(data, filters, environment=None):
    results = []
    for mandant in data:
        if environment and environment not in mandant:
            continue
        env_data = mandant.get(environment, {}) if environment else {}
        match = True
        for key, value in filters.items():
            if key == 'app_host':
                app_host = env_data.get('app/host', '')
                if value.lower() not in app_host.lower():  # Case-insensitive partial match
                    match = False
            elif key == 'namefull':
                namefull = env_data.get('namefull', '')
                if value.lower() not in namefull.lower():  # Case-insensitive partial match
                    match = False
        if match:
            results.append(env_data)
    return results

@app.route('/api/data/app/releaseversion', methods=['GET'])
def get_app_releaseversion():
    env = request.args.get('env')
    app_host = request.args.get('app_host')
    data = load_xml_data(xml_data_path)
    filters = {}
    if app_host:
        filters['app_host'] = app_host

    # Filter data
    environments = ['prod', 'test'] if not env else [env]
    response = []
    for mandant in data:
        for environment in environments:
            env_data = mandant.get(environment, {})
            if env_data and filter_data([mandant], filters, environment=environment):
                response.append({
                    'namefull': env_data.get('namefull', 'N/A'),
                    'app/releaseversion': env_data.get('app/releaseversion', 'N/A')
                })
    return jsonify(response), 200

@app.route('/api/data/database/host', methods=['GET'])
def get_database_host():
    env = request.args.get('env')
    namefull = request.args.get('namefull')
    data = load_xml_data(xml_data_path)
    filters = {'namefull': namefull} if namefull else {}
    filtered = filter_data(data, filters, environment=env)
    response = [{
        'namefull': item.get('namefull', 'N/A'),
        'database/host': item.get('database/host', 'N/A')
    } for item in filtered]
    return jsonify(response), 200

if __name__ == '__main__':
    app.run(port=api_port)


#from flask import Flask, jsonify, request
#import xml.etree.ElementTree as ET
#from collections import defaultdict
# 
# ******************************
# * CMI Configuration REST API *
# ******************************
# 
# PREREQUISITES
#     - install python3 (make available to all windows users)
#     - and packages: pip install Flask xmltodict (as administrator so that it's available to all users)
#     - The XML file with the CMI configuration must be present and accessible. Modify the path if nescessary.
#     - change api_port if you want to run it on a different port than 5001.
# 
# AUTHOR
#     Roger Rutishauser - DBA, October 2024
#