import asyncio
import random
import logging
from typing import List, Dict, Union
from playwright.async_api import async_playwright, TimeoutError as PlaywrightTimeoutError
from bs4 import BeautifulSoup
import trafilatura
import json
from modules.search.searxng_json import searxng_search
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class FastPlaywrightScraper:
    def __init__(self, headless: bool = True, timeout: int = 4000, max_parallel: int = 5):
        self.headless = headless
        self.timeout = timeout
        self.max_parallel = max_parallel

    async def scrape_page(self, page, url: str, main_selector: str = None) -> Dict[str, Union[str, bool]]:
        try:
            # Block heavy resources
            async def route_intercept(route, request):
                if request.resource_type in ["image", "media", "font", "stylesheet"]:
                    await route.abort()
                else:
                    await route.continue_()
            await page.route("**/*", route_intercept)

            # Go to page; no networkidle wait
            await page.goto(url, wait_until='domcontentloaded', timeout=self.timeout)

            # Optional: wait for main content briefly
            if main_selector:
                try:
                    await page.wait_for_selector(main_selector, timeout=1000)
                except PlaywrightTimeoutError:
                    logger.warning(f"⚠️ Selector '{main_selector}' not found for {url}")

            # Extract content immediately
            html_content = await page.content()
            title = await page.title()
            final_url = page.url

            extracted_content = trafilatura.extract(html_content, url=final_url)
            if not extracted_content:
                soup = BeautifulSoup(html_content, 'html.parser')
                extracted_content = soup.get_text(separator='\n', strip=True)

            return {
                "url": final_url,
                "title": title,
                "content": extracted_content[:8000] if extracted_content else "",
                "success": True,
                "html_length": len(html_content)
            }

        except PlaywrightTimeoutError:
            logger.warning(f"⚠️ Timeout fetching {url}")
            return {"url": url, "success": False, "error": "Timeout"}
        except Exception as e:
            logger.error(f"❌ Error fetching {url}: {e}")
            return {"url": url, "success": False, "error": str(e)}

    async def scrape_multiple(self, urls: List[str], main_selector: str = None) -> List[Dict]:
        async with async_playwright() as p:
            browser = await p.chromium.launch(headless=self.headless, args=[
                '--no-first-run',
                '--no-default-browser-check',
                '--disable-blink-features=AutomationControlled'
            ])
            context = await browser.new_context(
                viewport={'width': 1280, 'height': 720},
                user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
            )

            # Stealth mode
            await context.add_init_script("""
                Object.defineProperty(navigator, 'webdriver', {get: () => undefined});
                window.chrome = {runtime: {}};
                Object.defineProperty(navigator, 'plugins', {get: () => [1,2,3,4,5]});
                Object.defineProperty(navigator, 'languages', {get: () => ['en-US','en']});
            """)

            semaphore = asyncio.Semaphore(self.max_parallel)

            async def fetch(url):
                async with semaphore:
                    page = await context.new_page()
                    result = await self.scrape_page(page, url, main_selector=main_selector)
                    await page.close()
                    # tiny random delay to mimic human browsing
                    await asyncio.sleep(random.uniform(0.05, 0.2))
                    return result

            results = await asyncio.gather(*(fetch(url) for url in urls))
            await browser.close()
            return results


async def json_scrapped(query : str):
    url = searxng_search(query)
    scraper = FastPlaywrightScraper(
        headless=True,
        timeout=4000,   # max 4 sec
        max_parallel=10  # parallel scraping
    )

    results = await scraper.scrape_multiple(
        [url],
        main_selector="main, article, .Post"
    )

    # Convert to AI-friendly JSON format
    ai_docs = []
    for r in results:
        ai_docs.append({
            "url": r.get("url"),
            "title": r.get("title"),
            "success": r.get("success"),
            "content": (r.get("content") or "").strip(),
            "error": r.get("error")
        })

    return ai_docs

   

# Example usage
if __name__ == "__main__":
    async def main():
        query = "asia cup indian team 2025"
        ai_docs = await json_scrapped(query)
        # Print formatted JSON (ready for LLM)
        print(json.dumps(ai_docs, indent=2, ensure_ascii=False))

    asyncio.run(main())