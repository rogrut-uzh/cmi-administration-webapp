# routes/__init__.py
from flask import Blueprint

main = Blueprint('main', __name__)

# Importiere deine Unterdateien, damit die Routen registriert werden
from . import auth, views_general, views_cockpit, views_fulloverview, views_services, views_metatool
