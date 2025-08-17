# routes/middlewares/auth_middleware.py

from fastapi import Request, HTTPException
from routes.middlewares.check_jwt import verify_supabase_jwt

async def supabase_jwt_middleware(request: Request, call_next):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")

    token = auth_header.split(" ")[1]
    payload = verify_supabase_jwt(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid JWT token")

    # Optionally attach payload to request for later use
    request.state.user = payload
    response = await call_next(request)
    return response
