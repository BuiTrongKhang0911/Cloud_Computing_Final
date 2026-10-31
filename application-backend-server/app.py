import os
from functools import wraps

import jwt
import requests
from flask import Flask, jsonify, request

app = Flask(__name__)
KEYCLOAK_URL = os.getenv("KEYCLOAK_URL", "http://authentication-identity-server:8080")
KEYCLOAK_REALM = os.getenv("KEYCLOAK_REALM", "minicloud")
JWKS_URL = f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}/protocol/openid-connect/certs"
KEYCLOAK_ISSUER = os.getenv(
    "KEYCLOAK_ISSUER",
    f"{KEYCLOAK_URL}/realms/{KEYCLOAK_REALM}",
)


@app.get("/hello")
def hello():
    return jsonify(service="application-backend-server", message="Hello from MiniCloud")


def require_jwt(view):
    @wraps(view)
    def wrapped(*args, **kwargs):
        authorization = request.headers.get("Authorization", "")
        if not authorization.startswith("Bearer "):
            return jsonify(error="missing_bearer_token"), 401
        token = authorization[7:].strip()
        try:
            jwks = requests.get(JWKS_URL, timeout=5).json()
            header = jwt.get_unverified_header(token)
            key_data = next(key for key in jwks["keys"] if key["kid"] == header["kid"])
            public_key = jwt.algorithms.RSAAlgorithm.from_jwk(key_data)
            claims = jwt.decode(
                token,
                public_key,
                algorithms=["RS256"],
                issuer=KEYCLOAK_ISSUER,
                options={"verify_aud": False},
            )
            expected_client = os.getenv("KEYCLOAK_CLIENT_ID", "minicloud-app")
            if claims.get("azp") != expected_client and expected_client not in claims.get("aud", []):
                raise jwt.InvalidTokenError("unexpected token client")
        except (requests.RequestException, KeyError, ValueError, jwt.PyJWTError) as exc:
            app.logger.warning("JWT validation failed: %s", exc)
            return jsonify(error="invalid_bearer_token"), 401
        return view(claims, *args, **kwargs)

    return wrapped


@app.get("/secure")
@require_jwt
def secure(claims):
    return jsonify(service="application-backend-server", authenticated=True,
                   subject=claims.get("sub"))


@app.get("/health")
def health():
    return jsonify(status="healthy")


@app.get("/metrics")
def metrics():
    return "minicloud_application_up 1\n", 200, {"Content-Type": "text/plain; version=0.0.4"}
