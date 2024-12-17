from flask import Flask, jsonify, request
import xml.etree.ElementTree as ET
from collections import defaultdict
# 
# ******************************
# * CMI Configuration REST API *
# ******************************
# 
# PREREQUISITES
#     - install python3 (make available to all windows users)
#     - and packages: pip install Flask xmltodict (as administrator so that it's available to all users)
#     - Get caddy for reverse proxy. Put it to c:\caddy (currently installed: caddy_2.8.4_windows_amd64)
#     - The XML file with the CMI configuration must be present and accessible. Modify the path if nescessary.
#     - change api_port if you want to run it on a different port than 5001.
# 
xml_data_path = r'D:\gitlab\cmi-config\cmi-config.xml'
api_port = 5001
# 
# START
#     python .\cmi-config-rest-api.py
# 
# CADDY
#     - c:\caddy\caddy.exe run --config c:\caddy\Caddyfile
#     After changes on Caddyfile:
#     - c:\caddy\caddy.exe reload
# 
# LOGIC xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx modify! old!
#     The API logic is as follows:
# 
#     http://localhost:5001/api/data 
#     --> return whole content
# 
#     http://localhost:5001/api/data/prod 
#     --> return every mandant but only the prod section
# 
#     http://localhost:5001/api/data/test 
#     --> return every mandant but only the test section
# 
#     http://localhost:5001/api/data/prod/db 
#     --> return the db part of every mandant from prod
# 
#     http://localhost:5001/api/data/prod/db/name 
#     --> return the db name part of every mandant from prod
# 
#     http://localhost:5001/api/data/prod?nameFull=Bedarfsmanagement 
#     --> return the whole prod section of the mandant who has nameFull "Bedarfsfmanagement"
# 
#     http://localhost:5001/api/data/prod/db/name?nameShort=BM 
#     --> return the prod db name part of the mandant where nameShort is "BM"
# 
#     http://localhost:5001/api/data/prod/app/user?db_name=axioma_bm 
#     --> return the prod app user part of the mandant where db name is "axioma_bm"
# 
#     http://localhost:5001/api/data/prod/app/user?db_name=axioma_bm&app_lizenzserver=false 
#     --> return the prod app user part of the mandant where db name is "axioma_bm" and app lizenzserver is "false"
# 
# AUTHOR
#     Roger Rutishauser - DBA, October 2024
#

app = Flask(__name__)

# Rekursive Funktion zum Laden und Strukturieren der XML-Daten
def parse_element(element):
    # Wenn der Knoten keine Kinder hat, gib den Text zurück
    if len(element) == 0:
        return element.text.strip() if element.text else None
    
    # Andernfalls erstelle ein Dictionary für diesen Knoten
    result = defaultdict(list)
    for child in element:
        if len(child) > 0:
            # Rekursiver Aufruf, wenn der Knoten weitere Kinder hat
            result[child.tag] = parse_element(child)
#        elif child.tag == 'server':  # Spezifische Behandlung für mehrfach vorkommende `server`-Knoten
#            result['server'].append({
#                'name': child.attrib.get('name', ''),
#                'text': child.text.strip() if child.text else None
#            })
        elif child.tag in result:
            # Falls der Tag mehrfach vorkommt und kein `server`-Knoten ist, als Liste speichern
            if isinstance(result[child.tag], list):
                result[child.tag].append(child.text.strip() if child.text else None)
            else:
                result[child.tag] = [result[child.tag], child.text.strip() if child.text else None]
        else:
            result[child.tag] = child.text.strip() if child.text else None
    return dict(result)

# Funktion zum Laden und Strukturieren der XML-Daten der gesamten Datei
def load_xml_data(file_path):
    tree = ET.parse(file_path)
    root = tree.getroot()
    data = {'mandanten': []}

    for mandant in root.findall('mandant'):
        mandant_dict = {}

        # Verarbeite alle direkten Kinder von <mandant> außer 'prod' und 'test'
        for child in mandant:
            if child.tag not in ['prod', 'test']:
                mandant_dict[child.tag] = child.text.strip() if child.text else None

        # Verarbeite die 'prod' und 'test' Umgebungen
        for env in ['prod', 'test']:
            env_data = mandant.find(env)
            if env_data is not None:
                env_dict = {}

                for section in env_data:
                    # Benutze die rekursive Funktion, um jeden Abschnitt zu verarbeiten
                    env_dict[section.tag] = parse_element(section)

                # `prod` und `test` in das mandant_dict einfügen
                mandant_dict[env] = env_dict

        data['mandanten'].append(mandant_dict)

    return data

# Funktion zur Filteranwendung auf Mandantendaten basierend auf Query-Parametern
def apply_filters(mandant, filters, environment):
    env_data = mandant.get(environment, {})
    #print(env_data)
    for key, value in filters.items():
        keys = key.split('_')
        data = env_data

        for k in keys:
            #print(k)
            data = data.get(k)
            #print(data)
            if data is None:
                break

        if data is None or str(data) != str(value):
            return False

    return True

# Haupt-API-Endpunkt mit dynamischem Abschnitts-Handling
@app.route('/api/data/<environment>', defaults={'path_segments': ''}, methods=['GET'])
@app.route('/api/data/<environment>/<path:path_segments>', methods=['GET'])
def get_environment_data(environment, path_segments):
    data = load_xml_data(xml_data_path)
    mandanten = data.get('mandanten', [])
    
    filters = {key: value for key, value in request.args.items()}
    results = []

    path_keys = path_segments.split('/') if path_segments else []

    for mandant in mandanten:
        # Filter anwenden
        if filters and not apply_filters(mandant, filters, environment):
            continue

        # Get the environment-specific data
        env_data = mandant.get(environment, {})
        
        # Retrieve nameshort from the specified environment (prod or test)
        nameshort = env_data.get('nameshort', 'unknown')

        # Retrieve the specified path segment data
        selected_data = env_data
        for key in path_keys:
            selected_data = selected_data.get(key, {})
            if not selected_data:
                break

        results.append({nameshort: selected_data})

    return jsonify(results if results else {"message": "No matching data found"}), 200

if __name__ == '__main__':
    app.run(port=api_port)