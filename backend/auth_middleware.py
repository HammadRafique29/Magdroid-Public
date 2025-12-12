import os
import jwt
import requests
import json
from functools import wraps
from flask import request, jsonify

# Load configuration from environment variables
CLERK_ISSUER = os.getenv('CLERK_ISSUER')
CLERK_JWKS_URL = os.getenv('CLERK_JWKS_URL')

if not CLERK_ISSUER or not CLERK_JWKS_URL:
    raise Exception("CLERK_ISSUER and CLERK_JWKS_URL must be set in the environment.")

def get_jwks():
    """Fetch JWKS from the configured Clerk URL."""
    try:
        response = requests.get(CLERK_JWKS_URL)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        raise Exception(f"Failed to fetch JWKS from {CLERK_JWKS_URL}: {e}")

def validate_clerk_token(request):
    """Validate a Clerk JWT token using a configured JWKS URL and issuer."""
    auth_header = request.headers.get('Authorization')
    if not auth_header or not auth_header.startswith('Bearer '):
        raise Exception("Authorization header missing or invalid")

    token = auth_header.split('Bearer ')[1]

    try:
        # Fetch the JWKS
        jwks = get_jwks()
        
        # Get the Key ID (kid) from the token header
        headers = jwt.get_unverified_header(token)
        kid = headers.get('kid')
        if not kid:
            raise Exception("Key ID (kid) not found in token header")

        # Find the matching key in JWKS
        key = next((jwk for jwk in jwks['keys'] if jwk['kid'] == kid), None)
        if not key:
            raise Exception("Unable to find matching key in JWKS")

        # Convert the JWK to a public key
        rsa_key = jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(key))

        # Verify and decode the token
        decoded = jwt.decode(
            token,
            rsa_key,
            algorithms=['RS256'],
            issuer=CLERK_ISSUER
        )
        
        return decoded

    except jwt.ExpiredSignatureError:
        raise Exception("Token has expired")
    except jwt.InvalidTokenError as e:
        raise Exception(f"Invalid token: {str(e)}")
    except Exception as e:
        raise Exception(f"Token validation error: {str(e)}")
