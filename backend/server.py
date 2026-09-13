"""Carnet REST API. Python 3.11+, standard library only."""
import base64
import hashlib
import hmac
import json
import os
import re
import secrets
import sqlite3
import time
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DB = os.environ.get('DATABASE_PATH', 'carnet.sqlite3')
SECRET = os.environ.get('JWT_SECRET', '')
ACCESS_TTL = int(os.environ.get('ACCESS_TTL', '900'))

@contextmanager
def connect():
    db = sqlite3.connect(DB, timeout=10)
    db.row_factory = sqlite3.Row
    try:
        with db:
            yield db
    finally:
        db.close()

def initialize():
    with connect() as db:
        db.executescript('''
        CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY, name TEXT NOT NULL, email TEXT UNIQUE NOT NULL, password TEXT NOT NULL);
        CREATE TABLE IF NOT EXISTS sessions(id TEXT PRIMARY KEY, user_id INTEGER NOT NULL, refresh_hash TEXT NOT NULL, expires INTEGER NOT NULL);
        CREATE TABLE IF NOT EXISTS entries(kind TEXT NOT NULL, id INTEGER NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, label TEXT NOT NULL, PRIMARY KEY(kind,id));
        ''')
        data = json.loads(Path(__file__).with_name('seed.json').read_text())
        for kind, entries in data.items():
            db.executemany('INSERT OR IGNORE INTO entries VALUES(?,?,?,?,?)', [(kind, i+1, e[0], e[1], e[2]) for i, e in enumerate(entries)])

def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b'=').decode()

def password_hash(password, salt=None):
    salt = salt or secrets.token_hex(16)
    digest = hashlib.scrypt(password.encode(), salt=salt.encode(), n=16384, r=8, p=1).hex()
    return salt + ':' + digest

def jwt(user_id, session_id):
    header = b64(b'{"alg":"HS256","typ":"JWT"}')
    payload = b64(json.dumps({'sub': str(user_id), 'sid': session_id, 'exp': int(time.time()) + ACCESS_TTL, 'iss': 'carnet'}).encode())
    message = header + '.' + payload
    return message + '.' + b64(hmac.new(SECRET.encode(), message.encode(), hashlib.sha256).digest())

def issue(db, user_id, session_id=None):
    session_id = session_id or secrets.token_hex(24)
    refresh = secrets.token_urlsafe(48)
    db.execute('INSERT OR REPLACE INTO sessions VALUES(?,?,?,?)', (session_id, user_id, hashlib.sha256(refresh.encode()).hexdigest(), int(time.time()) + 604800))
    user = dict(db.execute('SELECT id,name,email FROM users WHERE id=?', (user_id,)).fetchone())
    return {'accessToken': jwt(user_id, session_id), 'refreshToken': refresh, 'user': user}

class ApiError(Exception):
    def __init__(self, status, message):
        self.status, self.message = status, message

class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        # Never log credentials, headers or request bodies.
        pass

    def send_json(self, status, body):
        content = json.dumps(body, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(content)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(content)

    def authenticate(self, db):
        try:
            token = self.headers.get('Authorization', '').removeprefix('Bearer ')
            head, payload, signature = token.split('.')
            expected = b64(hmac.new(SECRET.encode(), (head+'.'+payload).encode(), hashlib.sha256).digest())
            if not hmac.compare_digest(signature, expected):
                raise ValueError()
            claims = json.loads(base64.urlsafe_b64decode(payload + '=' * (-len(payload) % 4)))
            if claims['exp'] <= time.time() or claims['iss'] != 'carnet':
                raise ValueError()
            row = db.execute('SELECT * FROM sessions WHERE id=? AND user_id=? AND expires>?', (claims['sid'], claims['sub'], time.time())).fetchone()
            if row is None:
                raise ValueError()
            return claims
        except (ValueError, KeyError, TypeError):
            raise ApiError(401, 'Session expirée. Reconnectez-vous.')

    def do_GET(self):
        self.handle_request()

    def do_POST(self):
        self.handle_request()

    def handle_request(self):
        try:
            body = {}
            if self.command == 'POST':
                size = int(self.headers.get('Content-Length', '0'))
                if size > 16384 or size < 0:
                    raise ApiError(413, 'Requête trop volumineuse.')
                body = json.loads(self.rfile.read(size) or b'{}')
                if not isinstance(body, dict):
                    raise ApiError(400, 'Objet JSON requis.')
            with connect() as db:
                result, status = self.route(db, body)
            self.send_json(status, result)
        except ApiError as error:
            self.send_json(error.status, {'message': error.message})
        except (ValueError, TypeError, KeyError):
            self.send_json(400, {'message': 'Requête invalide.'})
        except Exception:
            self.send_json(500, {'message': 'Erreur serveur. Réessayez plus tard.'})

    def route(self, db, body):
        path = self.path.split('?')[0]
        if path == '/health' and self.command == 'GET':
            return {'status': 'ok'}, 200
        if path in ('/auth/register', '/auth/login') and self.command == 'POST':
            email = str(body.get('email', '')).strip().lower()
            password = str(body.get('password', ''))
            if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', email) or len(email) > 254 or not 8 <= len(password) <= 128:
                raise ApiError(400, 'Email valide et mot de passe de 8 à 128 caractères requis.')
            if path.endswith('register'):
                name = str(body.get('name', '')).strip()
                if not 2 <= len(name) <= 80:
                    raise ApiError(400, 'Le nom doit contenir 2 à 80 caractères.')
                try:
                    user_id = db.execute('INSERT INTO users(name,email,password) VALUES(?,?,?)', (name, email, password_hash(password))).lastrowid
                except sqlite3.IntegrityError:
                    raise ApiError(409, 'Cet email est déjà utilisé.')
                return issue(db, user_id), 201
            user = db.execute('SELECT * FROM users WHERE email=?', (email,)).fetchone()
            stored = user['password'] if user else password_hash('dummy-password')
            if not hmac.compare_digest(password_hash(password, stored.split(':')[0]), stored) or user is None:
                raise ApiError(401, 'Email ou mot de passe incorrect.')
            return issue(db, user['id']), 200
        if path == '/auth/refresh' and self.command == 'POST':
            hashed = hashlib.sha256(str(body.get('refreshToken', '')).encode()).hexdigest()
            db.execute('BEGIN IMMEDIATE')
            session = db.execute('SELECT * FROM sessions WHERE refresh_hash=? AND expires>?', (hashed, time.time())).fetchone()
            if session is None:
                raise ApiError(401, 'Session expirée. Reconnectez-vous.')
            return issue(db, session['user_id'], session['id']), 200
        claims = self.authenticate(db)
        if path == '/auth/logout' and self.command == 'POST':
            db.execute('DELETE FROM sessions WHERE id=?', (claims['sid'],))
            return {'message': 'Déconnecté'}, 200
        if path == '/auth/me' and self.command == 'GET':
            return dict(db.execute('SELECT id,name,email FROM users WHERE id=?', (claims['sub'],)).fetchone()), 200
        if self.command == 'GET' and path in ('/articles', '/products', '/tasks'):
            return {'items': [dict(r) for r in db.execute('SELECT id,title,body,label FROM entries WHERE kind=? ORDER BY id', (path[1:],))]}, 200
        raise ApiError(404, 'Ressource introuvable.')

if __name__ == '__main__':
    if len(SECRET) < 32:
        raise SystemExit('Configurez JWT_SECRET avec au moins 32 caractères aléatoires.')
    initialize()
    port = int(os.environ.get('PORT', '8000'))
    http = ThreadingHTTPServer((os.environ.get('HOST', '0.0.0.0'), port), Handler)
    print(f'Carnet API listening on port {http.server_port}', flush=True)
    http.serve_forever()
