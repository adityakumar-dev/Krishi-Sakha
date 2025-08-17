import json
import logging
import google.generativeai as genai
from configs.external_keys import GEMINI_API_KEY
from configs.model_config import ROUTER_CONFIG_DISCRIPTION_SYSTEM_PROMPT

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configure Gemini API
genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-2.0-flash')

def route_question(user_question: str) -> dict:
    """
    Use Gemini to determine which domain should handle the user's question.
    """
    try:
        prompt = f"{ROUTER_CONFIG_DISCRIPTION_SYSTEM_PROMPT}\n\nQuestion: \"{user_question}\""
        response = model.generate_content(prompt)
        response_text = response.text.strip()
        logger.info(f"Raw routing response: {response_text}")

        # Try extracting JSON
        try:
            start_idx = response_text.find('{')
            end_idx   = response_text.rfind('}') + 1
            if start_idx != -1 and end_idx != 0:
                json_str = response_text[start_idx:end_idx]
                routing_result = json.loads(json_str)
            else:
                routing_result = json.loads(response_text)
        except Exception:
            routing_result = {
                "domain": "general",
                "reason": "Failed to parse routing response, defaulting to general"
            }

        # Validate
        valid_domains = ["annual_report", "general", "search"]
        if routing_result.get("domain") not in valid_domains:
            routing_result = {
                "domain": "general",
                "reason": "Invalid domain returned, defaulting to general"
            }

        logger.info(f"Parsed routing result: {routing_result}")
        return routing_result
    except Exception as e:
        return {"domain":"general","reason":f"Error in routing: {str(e)}"}


def get_route_for_question(question: str) -> str:
    result = route_question(question)
    return result.get("domain", "general")


# ------------------------------------------------------------------------------

if __name__ == "__main__":
    test_question = input("Enter test question: ")
    result = route_question(test_question)
    print(f"\n→ ROUTER OUTPUT:\n{result}")
