
from fastapi import Request, HTTPException
from routes.middlewares.check_jwt import verify_supabase_jwt
from fastapi import Request, HTTPException, Depends
from routes.middlewares.check_jwt import verify_supabase_jwt

async def supabase_jwt_middleware(request: Request):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid Authorization header")

    token = auth_header.split(" ")[1]
    payload = verify_supabase_jwt(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Invalid JWT token")

    return payload
