from flask import Flask
from settings.config import Config
from routes import main

# Diese Imports sorgen dafür, dass alle Routen registriert werden
import routes.views_general
import routes.views_cockpit
import routes.cockpit
import routes.views_fulloverview
import routes.views_jobs
import routes.views_services
import routes.services
import routes.views_metatool
import routes.metatool
import routes.views_databases
import routes.databases


app = Flask(__name__)
app.config.from_object(Config)
app.register_blueprint(main)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
