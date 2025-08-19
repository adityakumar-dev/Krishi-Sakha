from fastapi import APIRouter, File, UploadFile, Form, Depends, HTTPException
from fastapi.responses import StreamingResponse
from typing import Optional
from io import BytesIO
from typing import List, Dict
import logging
from routes.middlewares.auth_middleware import supabase_jwt_middleware
logger = logging.getLogger(__name__)
router = APIRouter()
@router.post("/test")
async def test_endpoint(
    prompt: str = Form(...),
    conversation_id: str = Form(...),
    history: Optional[str] = Form(None),  # <--- change
    image: Optional[UploadFile] = File(None),
    user = Depends(supabase_jwt_middleware)
):
 
    logger.info(user)
    print(user)
    logger.info(f"Chat request from user: {prompt[:100]}...")
    return {"msg": "Test endpoint"}
