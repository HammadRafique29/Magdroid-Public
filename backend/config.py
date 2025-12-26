import os
from dotenv import load_dotenv

# Load environment variables from the .env file in the same directory.
# This makes the backend configuration self-contained.
dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
if os.path.exists(dotenv_path):
    load_dotenv(dotenv_path)
else:
    print(f"Warning: .env file not found at {dotenv_path}")

# --- Clerk Authentication ---
# CLERK_ISSUER = os.getenv('CLERK_ISSUER')
# CLERK_JWKS_URL = os.getenv('CLERK_JWKS_URL')

# --- CORS Configuration ---
CORS_ORIGINS = os.getenv('CORS_ORIGINS', '').split(',')

# --- Server Configuration ---
FLASK_RUN_PORT = os.getenv('BACKEND_PORT', 5000)

# --- Cloudflare Tunnels ---
CLOUDFLARED_TUNNEL_TOKEN = os.getenv('CLOUDFLARED_TUNNEL_TOKEN')

# --- Validation ---
# Ensure essential variables are loaded.
# if not CLERK_ISSUER:
#    print("FATAL: CLERK_ISSUER not found in backend/.env file.")
# if not CLERK_JWKS_URL:
#    print("FATAL: CLERK_JWKS_URL not found in backend/.env file.")
