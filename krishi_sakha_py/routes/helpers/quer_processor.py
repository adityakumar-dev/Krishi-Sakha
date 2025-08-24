import json
import logging
import google.generativeai as genai
from configs.external_keys import GEMINI_API_KEY
from configs.model_config import AI_SEARCH_SYSTEM_MESSAGE

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configure Gemini API
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-2.0-flash')


def preprocess_query(user_question: str) -> dict:
    """
    Use Gemini to determine which domain should handle the user's question.
    Returns a dictionary with domain, reason, year, and keywords.
    """
    try:
        prompt = f"{AI_SEARCH_SYSTEM_MESSAGE}\n\nQuestion: \"{user_question}\""
        response = model.generate_content(prompt)
        response_text = response.text.strip()
        logger.info(f"Raw routing response: {response_text}")

        # Try extracting JSON
        try:
            start_idx = response_text.find('{')
            end_idx   = response_text.rfind('}') + 1
            if start_idx != -1 and end_idx != 0:
                json_str = response_text[start_idx:end_idx]
                json_result = json.loads(json_str)
            else:
                json_result = json.loads(response_text)
        except Exception:
            json_result = {
                "query" : user_question,
                "search" : "",
            }

        logger.info(f"Parsed routing result: {json_result}")
        return json_result

    except Exception as e:
        return {
            "domain": "general",
            "reason": f"Error in routing: {str(e)}",
            "year": None,
            "keywords": []
        }


# ------------------------------------------------------------------------------

if __name__ == "__main__":
    test_question = input("Enter test question: ")
    result = preprocess_query(test_question)
    print(f"\n→ ROUTER OUTPUT:\n{result}")
