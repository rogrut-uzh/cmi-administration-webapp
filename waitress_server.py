# waitress_server.py
########################################
# 
#    Waitress ist ein leistungsstarker WSGI-Server, der für die Produktion entwickelt wurde
#    und besser mit hohen Lasten und vielen gleichzeitigen Anfragen umgehen kann.
#    
#    Der eingebaute Flask-Server ist hauptsächlich für Entwicklungszwecke gedacht
#    und nicht für den Einsatz in der Produktion geeignet, da er nicht gut skaliert.
#    
# 
#######################################
# pip install waitress
from waitress import serve
from app import app

serve(app, listen='0.0.0.0:5000', threads=4)
