# routes/helpers/auth_helper.py

import os
import jwt
from jwt import InvalidTokenError
from configs.supabase_key import SUPABASE_LEGACY_JWT_KEY

def verify_supabase_jwt(token: str) -> dict | None:
    """
    Verify a Supabase JWT token using the legacy JWT key.

    Args:
        token (str): JWT token from user request

    Returns:
        dict | None: Decoded payload if valid, None if invalid
    """
    try:
        payload = jwt.decode(
            token,
            SUPABASE_LEGACY_JWT_KEY,
            algorithms=["HS256"],  # Supabase uses HS256 for legacy JWTs
            options={"verify_aud": False}  # skip audience verification
        )
        return payload
    except InvalidTokenError as e:
        print(f"❌ Invalid Supabase JWT: {e}")
        return None
