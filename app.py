# app.py
from flask import Flask
from settings.config import Config
from routes import main

app = Flask(__name__)
app.config.from_object(Config)
app.register_blueprint(main)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
