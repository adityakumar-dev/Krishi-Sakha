import requests

def searxng_search(query: str, instance_url: str = "http://localhost:8080", max_results: int = 10):
    """
    Fetch only the result URLs from a SearxNG instance in JSON format.
    """
    url = f"{instance_url}/search"
    params = {
        "q": query,
        "format": "json",
        "categories": "general",
        "language": "en",
        "safesearch": 1,
        "count": max_results
    }
    headers = {
        "User-Agent": "Mozilla/5.0"
    }
    response = requests.get(url, params=params, headers=headers, timeout=10)
    if response.status_code == 200:
        data = response.json()
        # Extract URLs only
        return [result["url"] for result in data.get("results", []) if "url" in result]
    else:
        response.raise_for_status()

if __name__ == "__main__":
    import sys
    query = sys.argv[1] if len(sys.argv) > 1 else "asia cup indian team 2025"
    urls = searxng_search(query)
    for u in urls:
        print(u)
