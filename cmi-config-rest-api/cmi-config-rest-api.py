################################
# * CMI Configuration REST API #
################################
# 
# PREREQUISITES
#     - install python3 (make available to all windows users)
#     - and packages: pip install Flask xmltodict (as administrator so that it's available to all users)
#     - The XML file with the CMI configuration must be present and accessible. Modify the path if nescessary.
#     - change api_port if you want to run it on a different port than 5001.
# 
# AUTHOR
#     Roger Rutishauser - DBA, October-December 2024
#
from flask import Flask, jsonify, request
import xml.etree.ElementTree as ET
app = Flask(__name__)

################### change if nescessary ###############
xml_data_path = 'D:\gitlab\cmi-config\cmi-config-v2.xml'
api_port = 5001
########################################################

def load_xml_data(file_path):
    def parse_element(element):
        """Recursively parse an XML element into a dictionary."""
        if len(element) == 0:  # No children, return text or None
            return element.text.strip() if element.text else None
        parsed_data = {}
        for child in element:
            # Handle multiple nodes with the same tag
            if child.tag not in parsed_data:
                parsed_data[child.tag] = parse_element(child)
            else:
                if not isinstance(parsed_data[child.tag], list):
                    parsed_data[child.tag] = [parsed_data[child.tag]]
                parsed_data[child.tag].append(parse_element(child))
        return parsed_data

    tree = ET.parse(file_path)
    root = tree.getroot()
    data = {}

    for section in ['cmi', 'ais']:
        section_data = []
        section_root = root.find(section)
        if section_root is not None:
            for env in ['prod', 'test']:
                env_data = section_root.find(env)
                if env_data is not None:
                    for mandant in env_data.findall('mandant'):
                        mandant_data = {
                            'environment': env,  # Add environment info
                        }
                        # Dynamically parse all children of <mandant>
                        mandant_data.update({child.tag: parse_element(child) for child in mandant})
                        section_data.append(mandant_data)
        data[section] = section_data
    return data

def filter_data(data, filters):
    filtered = []
    for mandant in data:
        match = True
        for key, value in filters.items():
            # Flatten keys for filtering (e.g., 'app/releaseversion')
            keys = key.split('/')
            target = mandant
            for k in keys:
                if isinstance(target, dict) and k in target:
                    target = target[k]
                else:
                    match = False
                    break
            if match and value.lower() not in str(target).lower():
                match = False
        if match:
            filtered.append(mandant)
    return filtered

@app.route('/api/data', methods=['GET'])
def get_all_data():
    data = load_xml_data(xml_data_path)
    filters = request.args.to_dict()
    response = data['cmi'] + data['ais']
    if filters:
        response = filter_data(response, filters)
    return jsonify(response), 200

@app.route('/api/data/<section>', methods=['GET'])
def get_section_data(section):
    data = load_xml_data(xml_data_path)
    if section not in data:
        return jsonify({'error': f'Section "{section}" not found.'}), 404
    filters = request.args.to_dict()
    response = data[section]
    if filters:
        response = filter_data(response, filters)
    return jsonify(response), 200

@app.route('/api/data/<section>/<environment>', methods=['GET'])
def get_section_environment_data(section, environment):
    data = load_xml_data(xml_data_path)
    if section not in data:
        return jsonify({'error': f'Section "{section}" not found.'}), 404
    environment_data = [mandant for mandant in data[section] if mandant.get('environment') == environment]
    filters = request.args.to_dict()
    response = environment_data
    if filters:
        response = filter_data(environment_data, filters)
    return jsonify(response), 200

if __name__ == '__main__':
    app.run(port=api_port)




