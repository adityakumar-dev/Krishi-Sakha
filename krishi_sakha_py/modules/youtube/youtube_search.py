#!/usr/bin/env python3
"""
YouTube Search Helper
Fetch YouTube search results without API key (via HTML scraping).
"""

import json
import requests
import urllib.parse
import re
from typing import Dict, List


def search_youtube(query: str, limit: int = 10) -> List[Dict]:
    """
    Search YouTube and return video details as a list of dictionaries.
    """
    # Encode query
    encoded_query = urllib.parse.quote_plus(query)
    url = f"https://www.youtube.com/results?search_query={encoded_query}"

    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/91.0.4472.124 Safari/537.36"
        )
    }

    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        html_content = response.text

        # Extract ytInitialData JSON
        match = re.search(r"var ytInitialData = ({.*?});", html_content)
        if not match:
            raise ValueError("Could not find ytInitialData in page")

        data = json.loads(match.group(1))

        # Parse results
        videos = []
        contents = (
            data.get("contents", {})
            .get("twoColumnSearchResultsRenderer", {})
            .get("primaryContents", {})
            .get("sectionListRenderer", {})
            .get("contents", [])
        )

        for section in contents:
            items = section.get("itemSectionRenderer", {}).get("contents", [])
            for item in items:
                if "videoRenderer" not in item:
                    continue

                video = item["videoRenderer"]

                videos.append({
                    "title": video.get("title", {}).get("runs", [{}])[0].get("text", ""),
                    "video_id": video.get("videoId", ""),
                    "url": f"https://www.youtube.com/watch?v={video.get('videoId', '')}",
                    "thumbnail": video.get("thumbnail", {}).get("thumbnails", [{}])[-1].get("url", ""),
                    "channel": video.get("ownerText", {}).get("runs", [{}])[0].get("text", ""),
                    "channel_url": "https://www.youtube.com" + video.get("ownerText", {}).get("runs", [{}])[0]
                        .get("navigationEndpoint", {})
                        .get("commandMetadata", {})
                        .get("webCommandMetadata", {})
                        .get("url", ""),
                    "duration": video.get("lengthText", {}).get("simpleText", ""),
                    "views": video.get("viewCountText", {}).get("simpleText", ""),
                    "published": video.get("publishedTimeText", {}).get("simpleText", ""),
                })

                if len(videos) >= limit:
                    return videos

        return videos

    except Exception as e:
        return [{"error": str(e)}]


if __name__ == "__main__":
    query = input("Enter search query: ")
    results = search_youtube(query, limit=5)
    print(json.dumps(results, indent=2, ensure_ascii=False))
