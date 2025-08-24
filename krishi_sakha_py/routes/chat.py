from fastapi import APIRouter, UploadFile, File, Form, Depends
from fastapi.responses import StreamingResponse
from typing import Optional, List, Any
import json
import logging

from routes.middlewares.auth_middleware import supabase_jwt_middleware
from brain.model_run import model_runner
from routes.helpers.router_picker import route_question
from routes.helpers.push_supabase import push_to_supabase
from data.functions.add_to_vector_db import PDFVectorDBManager
from modules.scrapper.scrapper import json_scrapped
from typing import Dict
from modules.youtube.youtube_search import search_youtube
logger = logging.getLogger(__name__)
router = APIRouter()


def flatten_docs(docs: List[Any]) -> List[str]:
    """
    Recursively flatten a list of documents which may contain strings or nested lists of strings.
    Returns a flat list of strings.
    """
    flat_list = []
    for doc in docs:
        if isinstance(doc, str):
            flat_list.append(doc)
        elif isinstance(doc, list):
            flat_list.extend(flatten_docs(doc))
        else:
            flat_list.append(str(doc))
    return flat_list
@router.post("/chat")
async def chat_endpoint(
    prompt: str = Form(...),
    conversation_id: str = Form(...),
    image: Optional[UploadFile] = File(None),
    history:str = Form(None),
    user=Depends(supabase_jwt_middleware)
):
    user_id = user.get("sub")
    logger.info(f"User: {user_id}, Conversation: {conversation_id}")
    if history:
        history = json.loads(history)
    # Read image bytes ONLY ONCE here:
    image_bytes = None
    if image:
        image_bytes = await image.read()
        logger.info(f"Read {len(image_bytes)} bytes from image")

    async def event_stream():
        try:
            # ---------------------------------------------------------------------
            # IMAGE REQUEST
            # ---------------------------------------------------------------------
            if image_bytes:
                yield f"data: {json.dumps({'type': 'status', 'message': 'Processing uploaded image...'})}\n\n"

                import os
                temp_dir = "./temp"
                os.makedirs(temp_dir, exist_ok=True)
                
                # Use a safe filename with proper extension
                file_extension = image.filename.split('.')[-1] if image.filename and '.' in image.filename else 'jpg'
                image_path = f"{temp_dir}/image_{conversation_id}.{file_extension}"

                try:
                    with open(image_path, "wb") as f:
                        f.write(image_bytes)
                    logger.info(f"Saved temp image to {image_path}")

                    final_query = prompt if prompt.strip() else "What do you see in this image?"

                    async for chunk in model_runner.generate_image(
                        question=final_query,
                        conversation_id=conversation_id,
                        user_id=user_id,
                        image_path=image_path,
                        stream=True,
                        # history=history
                    ):
                        yield f"data: {json.dumps({'type': 'text', 'chunk': chunk})}\n\n"

                    # Done
                    yield "data: {\"type\": \"complete\"}\n\n"

                except Exception as image_error:
                    logger.error(f"Error processing image: {str(image_error)}")
                    yield f"data: {json.dumps({'type': 'error', 'message': f'Error processing image: {str(image_error)}'})}\n\n"

                finally:
                    # Clean up temp file
                    try:
                        if os.path.exists(image_path):
                            os.remove(image_path)
                            logger.info("Temp image removed")
                    except Exception as cleanup_err:
                        logger.warning(f"Failed to cleanup temp image: {cleanup_err}")

                return  # Stop here (do not go to text flow)

            # ---------------------------------------------------------------------
            # TEXT-ONLY REQUEST
            # ---------------------------------------------------------------------
            yield f"data: {json.dumps({'type': 'status', 'message': 'Processing query...'})}\n\n"
            yield f"data: {json.dumps({'type': 'status', 'message': 'Routing query...'})}\n\n"

            routing = route_question(prompt)
            logger.info(f"Routing result: {routing}")

            domain = routing.get("domain", "general")
            keywords = routing.get("keywords", [])
            query = routing.get("query", prompt)

            # Initialize variables
            context = ""
            youtube_urls = []

            # Retrieve context if needed
            if domain != "general":
                if domain != "search":
                    yield f"data: {json.dumps({'type': 'status', 'message': 'Searching for context...'})}\n\n"
                    db_manager = PDFVectorDBManager(
                        vector_db_type="chroma",
                        embedding_method="sentence_transformers",
                        db_path="/home/linmar/Desktop/Krishi-Sakha/krishi_sakha_py/chroma_db",
                        collection_name=domain
                    )

                    search_query = " ".join(keywords) if keywords else prompt
                    results = db_manager.search_documents(query=search_query, n_results=5)
                    if not results.get("documents") or results["documents"] == [[]]:
                        results = db_manager.search_documents(query=prompt, n_results=5)
                    docs_flat = flatten_docs(results.get("documents", []))
                    context = "\n".join(docs_flat) if docs_flat else ""

                    yield f"data: {json.dumps({'type': 'status', 'message': f'Context found: {len(docs_flat)} documents'})}\n\n"
                else:
                    yield f"data: {json.dumps({'type': 'status', 'message': 'Searching on YouTube...'})}\n\n"
                    youtube_urls = search_youtube(query, limit=5)  # Limit to 5 results
                    
                    yield f"data: {json.dumps({'type': 'status', 'message': 'Searching on the internet...'})}\n\n"
                    context = await json_scrapped(query)
                    
                    # Extract and send URLs immediately
                    urls = []
                    for item in context:
                        if "url" in item:
                            if isinstance(item["url"], list):
                                urls.extend(item["url"])
                            else:
                                urls.append(item["url"])
                    
                    # Send URLs as separate event
                    yield f"data: {json.dumps({'type': 'urls', 'urls': urls})}\n\n"
                    
                    # Send YouTube results as separate event with proper encoding
                    try:
                        # Clean the YouTube results to ensure JSON compatibility
                        cleaned_results = []
                        for result in youtube_urls:
                            cleaned_result = {}
                            for key, value in result.items():
                                if isinstance(value, str):
                                    # Ensure proper encoding and remove any problematic characters
                                    cleaned_result[key] = value.encode('utf-8', 'ignore').decode('utf-8')
                                else:
                                    cleaned_result[key] = value
                            cleaned_results.append(cleaned_result)
                        
                        youtube_json = json.dumps({'type': 'youtube', 'results': cleaned_results}, ensure_ascii=False)
                        yield f"data: {youtube_json}\n\n"
                    except Exception as json_error:
                        logger.error(f"Error serializing YouTube results: {json_error}")
                        yield f"data: {json.dumps({'type': 'youtube', 'results': []})}\n\n"
            # Stream normal model
            yield f"data: {json.dumps({'type': 'status', 'message': 'Generating response...'})}\n\n"

            # Collect the full response for saving to DB
            full_response = ""
            async for chunk in model_runner.generate(
                question=prompt,
                context="Internet web scrapper result : " + json.dumps(context) if domain == "search" else context,
                conversation_id=conversation_id,
                user_id=user_id,
                stream=True,
                history=history,
                metadata=None,  # No metadata needed since we send events directly
                push_to_db=False  # Prevent automatic DB save to avoid duplicates
            ):
                full_response += chunk
                yield f"data: {json.dumps({'type': 'text', 'chunk': chunk})}\n\n"

            # Save the complete response to database (single save)
            if full_response:
                # Only include metadata for database storage when domain is search
                metadata_for_db = None
                if domain == "search":
                    urls = []
                    for item in context:
                        if "url" in item:
                            if isinstance(item["url"], list):
                                urls.extend(item["url"])
                            else:
                                urls.append(item["url"])
                    metadata_for_db = {
                        'url': urls,
                        'youtberelated': youtube_urls if 'youtube_urls' in locals() else []
                    }
                
                push_to_supabase(
                    'chat_messages',
                    {
                        'conversation_id': conversation_id,
                        'user_id': user_id,
                        'message': full_response,
                        'sender': "assistant",
                        'metadata': metadata_for_db
                    }
                )                

                

            yield f"data: {json.dumps({'type': 'complete'})}\n\n"



        except Exception as e:
            logger.error(f"General error in chat endpoint: {str(e)}", exc_info=True)
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")
