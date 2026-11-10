import json
import os
from functools import wraps
from pathlib import Path

import jwt
import mysql.connector
import requests
from flask import Flask, jsonify, request

app = Flask(__name__)
KEYCLOAK_URL = os.getenv("KEYCLOAK_URL", "http://authentication-identity-server:8080")


def _realm_config(realm_env, client_env, issuer_env, default_realm, default_client):
    realm = os.getenv(realm_env, default_realm)
    return {
        "realm": realm,
        "client_id": os.getenv(client_env, default_client),
        "issuer": os.getenv(issuer_env, f"http://localhost:8081/realms/{realm}"),
        "jwks_url": f"{KEYCLOAK_URL}/realms/{realm}/protocol/openid-connect/certs",
    }


TOKEN_REALMS = [
    _realm_config("KEYCLOAK_REALM", "KEYCLOAK_CLIENT_ID", "KEYCLOAK_ISSUER", "minicloud", "minicloud-app"),
    _realm_config(
        "KEYCLOAK_EXTRA_REALM",
        "KEYCLOAK_EXTRA_CLIENT_ID",
        "KEYCLOAK_EXTRA_ISSUER",
        "realm_sv001",
        "flask-app",
    ),
]

DATABASE_CONFIG = {
    "host": os.getenv("DATABASE_HOST", "relational-database-server"),
    "port": int(os.getenv("DATABASE_PORT", "3306")),
    "database": os.getenv("DATABASE_NAME", "minicloud"),
    "user": os.getenv("DATABASE_USER", "minicloud_user"),
    "password": os.getenv("DATABASE_PASSWORD", ""),
    "connection_timeout": 3,
}


def _query_rows(database, query):
    config = {**DATABASE_CONFIG, "database": database}
    connection = mysql.connector.connect(**config)
    try:
        cursor = connection.cursor(dictionary=True)
        cursor.execute(query)
        return cursor.fetchall()
    finally:
        connection.close()


@app.get("/hello")
def hello():
    return jsonify(message="Hello from App Server!")


@app.get("/student")
def students_from_json():
    data_path = Path(__file__).with_name("students.json")
    with data_path.open(encoding="utf-8") as student_file:
        return jsonify(json.load(student_file))


@app.get("/db/services")
def database_services():
    try:
        rows = _query_rows("minicloud", "SELECT id, name, description FROM services ORDER BY id")
        return jsonify(services=rows)
    except mysql.connector.Error:
        app.logger.exception("Database query failed")
        return jsonify(error="database_unavailable"), 503


@app.get("/students-db")
def students_from_database():
    try:
        rows = _query_rows(
            "studentdb",
            "SELECT id, student_id, fullname, dob, major FROM students ORDER BY id",
        )
        for row in rows:
            row["dob"] = row["dob"].isoformat() if row["dob"] else None
        return jsonify(students=rows)
    except mysql.connector.Error:
        app.logger.exception("Student database query failed")
        return jsonify(error="student_database_unavailable"), 503


def _validate_token(token):
    header = jwt.get_unverified_header(token)
    for realm in TOKEN_REALMS:
        try:
            jwks_response = requests.get(realm["jwks_url"], timeout=5)
            jwks_response.raise_for_status()
            jwks = jwks_response.json()
            key_data = next(key for key in jwks["keys"] if key["kid"] == header["kid"])
            public_key = jwt.algorithms.RSAAlgorithm.from_jwk(key_data)
            claims = jwt.decode(
                token,
                public_key,
                algorithms=["RS256"],
                issuer=realm["issuer"],
                options={"verify_aud": False},
            )
            if claims.get("azp") != realm["client_id"] and realm["client_id"] not in claims.get("aud", []):
                continue
            return claims
        except (requests.RequestException, KeyError, StopIteration, ValueError, jwt.PyJWTError):
            continue
    raise jwt.InvalidTokenError("token is not valid for an allowed client and realm")


def require_jwt(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        authorization = request.headers.get("Authorization", "")
        if not authorization.startswith("Bearer "):
            return jsonify(error="missing_bearer_token"), 401
        try:
            claims = _validate_token(authorization[7:].strip())
        except (requests.RequestException, KeyError, ValueError, jwt.PyJWTError) as exc:
            app.logger.warning("JWT validation failed: %s", exc)
            return jsonify(error="invalid_bearer_token"), 401
        return view(claims, *args, **kwargs)

    return wrapped


@app.get("/secure")
@require_jwt
def secure(claims):
    return jsonify(service="application-backend-server", authenticated=True,
                   preferred_username=claims.get("preferred_username"), subject=claims.get("sub"))


@app.get("/health")
def health():
    return jsonify(status="healthy")


@app.get("/metrics")
def metrics():
    return "minicloud_application_up 1\n", 200, {"Content-Type": "text/plain; version=0.0.4"}
