import json
import os
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from unittest.mock import patch
import server

class ApiTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        server.DB = os.path.join(cls.temp.name, 'test.sqlite3')
        server.SECRET = 'test-secret-not-for-production-123456789'
        server.initialize()
        cls.http = server.ThreadingHTTPServer(('127.0.0.1', 0), server.Handler)
        cls.base = f'http://127.0.0.1:{cls.http.server_port}'
        cls.thread = threading.Thread(target=cls.http.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.http.shutdown()
        cls.http.server_close()
        cls.thread.join()
        cls.temp.cleanup()

    def request(self, path, body=None, token=None):
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        request = urllib.request.Request(self.base + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=5) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as error:
            with error:
                return error.code, json.load(error)

    def register(self, email):
        status, session = self.request('/auth/register', {'name': 'Alice', 'email': email, 'password': 'password123'})
        self.assertEqual(status, 201)
        return session

    def test_register_login_refresh_logout_and_three_feeds(self):
        session = self.register('alice@test.dev')
        self.assertEqual(self.request('/auth/login', {'email': 'alice@test.dev', 'password': 'wrongpass'})[0], 401)
        self.assertEqual(self.request('/auth/login', {'email': 'alice@test.dev', 'password': 'password123'})[0], 200)
        for path in ['/articles', '/products', '/tasks']:
            status, body = self.request(path, token=session['accessToken'])
            self.assertEqual(status, 200)
            self.assertEqual(len(body['items']), 4)
            self.assertEqual(self.request(path)[0], 401)
        status, renewed = self.request('/auth/refresh', {'refreshToken': session['refreshToken']})
        self.assertEqual(status, 200)
        self.assertNotEqual(session['refreshToken'], renewed['refreshToken'])
        self.assertEqual(self.request('/auth/refresh', {'refreshToken': session['refreshToken']})[0], 401)
        self.assertEqual(self.request('/auth/logout', {}, renewed['accessToken'])[0], 200)
        self.assertEqual(self.request('/articles', token=renewed['accessToken'])[0], 401)
        self.assertEqual(self.request('/auth/refresh', {'refreshToken': renewed['refreshToken']})[0], 401)

    def test_validation_and_duplicate_email(self):
        self.assertEqual(self.request('/auth/register', {'name': 'A', 'email': 'bad', 'password': 'short'})[0], 400)
        self.register('duplicate@test.dev')
        self.assertEqual(self.request('/auth/register', {'name': 'Alice', 'email': 'duplicate@test.dev', 'password': 'password123'})[0], 409)

    def test_expired_and_tampered_access_tokens(self):
        with patch.object(server, 'ACCESS_TTL', -1):
            session = self.register('expired@test.dev')
        self.assertEqual(self.request('/articles', token=session['accessToken'])[0], 401)
        self.assertEqual(self.request('/articles', token=session['accessToken']+'x')[0], 401)
        self.assertEqual(self.request('/auth/refresh', {'refreshToken': session['refreshToken']})[0], 200)

if __name__ == '__main__':
    unittest.main()
