from fastapi import APIRouter, File, UploadFile, Form, Depends, HTTPException
from fastapi.responses import StreamingResponse
from typing import Optional
import logging
import json
from io import BytesIO

# Local imports
from routes.middlewares.auth_middleware import supabase_jwt_middleware
from brain.model_run import model_runner
from routes.helpers.router_picker import route_question
from routes.helpers.push_supabase import get_user_chat_history

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

router = APIRouter()


@router.post("/chat")
async def chat_endpoint(
    prompt: str = Form(...),
    conversation_id : str = Form(...),
    history : Optional[List(Map[str, str])] = None,
    image : Optional[UploadFile] = File(None),  #for current working we will skip this   
    request = None
):
    """
    Chat endpoint supporting text prompt + optional image with streaming RAG responses.
    Supports both streaming and non-streaming responses.
    """
    try:
        # Extract user info from JWT middleware (if implemented)
        user_id = "anonymous"  # Default fallback
        
        # Try to get user from request state if JWT middleware is active
        if hasattr(request, 'state') and hasattr(request.state, 'user'):
            user_id = request.state.user.get('sub', 'anonymous')
        
        logger.info(f"Chat request from user: {user_id}, prompt: {prompt[:100]}...")
        
        # Handle image processing if provided
        if image:
            # For now, we'll log that an image was provided
            # In the future, this could be processed with vision models
            logger.info(f"Image uploaded: {image.filename}, size: {image.size}")
            # You could add image processing logic here
            # For now, we'll just include it in the prompt context
            prompt = f"[Image uploaded: {image.filename}] {prompt}"
        
        
            # Return streaming response
            async def generate_stream():
                try:
                    async for chunk in model_runner.generate_response(
                        query=prompt,
                        user_id=user_id,
                        use_voice_model=use_voice_model,
                        stream=True
                    ):
                        # Format as Server-Sent Events
                        yield f"data: {json.dumps({'chunk': chunk, 'type': 'text'})}\n\n"
                    
                    # Send completion signal
                    yield f"data: {json.dumps({'type': 'complete'})}\n\n"
                    
                except Exception as e:
                    error_msg = f"Error in streaming: {str(e)}"
                    logger.error(error_msg)
                    yield f"data: {json.dumps({'error': error_msg, 'type': 'error'})}\n\n"
            
            return StreamingResponse(
                generate_stream(),
                media_type="text/plain",
                headers={
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                    "Content-Type": "text/event-stream"
                }
            )
    except Exception as e:
        logger.error(f"Error in chat endpoint: {e}")
        raise HTTPException(status_code=500, detail=str(e))

