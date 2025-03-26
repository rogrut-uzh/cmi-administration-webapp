# config.py
import secrets

class Config:
    SERVER_NAME = 'localhost:5000'
    APPLICATION_ROOT = '/'
    PREFERRED_URL_SCHEME = 'http'
    SECRET_KEY = secrets.token_hex(16)  # Setze hier deinen geheimen Schlüssel
