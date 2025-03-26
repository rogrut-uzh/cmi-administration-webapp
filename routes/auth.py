# routes/auth.py
from flask import request, Response
from functools import wraps
import os

def check_auth(username, password):
    return username == os.getenv("CMI_WEBAPP_BASICAUTH_USER") and password == os.getenv("CMI_WEBAPP_BASICAUTH_PW")

def authenticate():
    return Response(
        'Unauthorized', 401,
        {'WWW-Authenticate': 'Basic realm="Login Required"'}
    )

def requires_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth = request.authorization
        if not auth or not check_auth(auth.username, auth.password):
            return authenticate()
        return f(*args, **kwargs)
    return decorated
