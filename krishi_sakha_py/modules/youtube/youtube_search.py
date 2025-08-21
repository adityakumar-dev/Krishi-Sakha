import subprocess
import json

def youtube_search(query : str, limit : int = 3) -> list:
    try:
        cmd = ["yt-dlp", f"ytsearch{limit}:{query}","--dump-json", "--no-warnings","--skip-download"]
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        videos = [json.loads(line) for line in result.stdout.strip().split("\n") if line.strip()]   
        return [{
            "title": v.get("title"),
            "url": v.get("webpage_url"),
            "thumbnail": v.get("thumbnail"),
            "duration": v.get("duration_string") or format_duration(v.get("duration")),
            } for v in videos]

    except subprocess.CalledProcessError as e:
        return [{"error": f"Search failed: {e}"}]
def format_duration(seconds):
    if not seconds:
        return ""
    minutes, sec = divmod(seconds, 60)
    return f"{minutes}:{sec:02}"


if __name__ == "__main__":
    results = youtube_search("quak quak")
    for result in results:
        print(f"{result}\n")