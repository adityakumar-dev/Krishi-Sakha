from modules.scrapper.scrapper import json_scrapped
from modules.youtube.youtube_search import search_youtube
from fastapi import APIRouter, Request
from brain.model_run import model_runner
from fastapi.responses import StreamingResponse
import json
from routes.helpers.quer_processor import preprocess_query
import logging
router = APIRouter()
logger = logging.getLogger(__name__)


@router.post("/search")
async def search(request: Request):
    data = await request.json()
    query = data.get("query")

    async def event_stream():
        try:
            yield f"data: {json.dumps({'type': 'status', 'message': 'Processing query...'})}\n\n"
            preprocessed_query = preprocess_query(query)
            search_query = preprocessed_query.get("search", query)
            yield f"data: {json.dumps({'type': 'status', 'message': 'Searching for results...'})}\n\n"
            scrapped_data = await json_scrapped(search_query)
            yield f"data: {json.dumps({'type': 'status', 'message': 'Scraped data retrieved.'})}\n\n"
            
            # Extract and send URLs immediately
            urls = []
            for item in scrapped_data:
                if "url" in item:
                    if isinstance(item["url"], list):
                        urls.extend(item["url"])
                    else:
                        urls.append(item["url"])
            
            # Send URLs as separate event
            yield f"data: {json.dumps({'type': 'urls', 'urls': urls})}\n\n"
            
            yield f"data: {json.dumps({'type': 'status', 'message': 'Searching YouTube results...'})}\n\n"
            youtube_results = search_youtube(search_query, limit=5)  # Limit to 5 results to avoid large payloads
            yield f"data: {json.dumps({'type': 'status', 'message': 'YouTube results retrieved.'})}\n\n"
            
            # Send YouTube results as separate event - ensure it's properly serialized
            try:
                # Clean the YouTube results to ensure JSON compatibility
                cleaned_results = []
                for result in youtube_results:
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
            
            yield f"data: {json.dumps({'type': 'status', 'message': 'Processing model response...'})}\n\n"
            # Stream model response directly (no collection needed)
            async for chunk in model_runner.run_rag(query, scrapped_data):
                yield f"data: {json.dumps({'type': 'text', 'chunk': chunk})}\n\n"
           
            yield f"data: {json.dumps({'type': 'complete'})}\n\n"
        except Exception as e:
            logger.error(f"General error in search endpoint: {str(e)}", exc_info=True)
            yield f"data: {json.dumps({'type': 'error', 'message': str(e)})}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")
