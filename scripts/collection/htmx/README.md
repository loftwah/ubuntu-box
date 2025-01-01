# HTMX CEO Tier List Tools

This directory contains scripts and resources for generating an HTMX CEO tier list. The process includes scraping data from the HTMX CEO website, enriching it with Twitter profile details, and identifying the top CEOs for the tier list.

## Directory Structure
```
.
├── images/                     # Directory containing downloaded Twitter profile images
├── ceos.json                   # Scraped CEO names and Twitter URLs
├── ceos_with_followers.json    # Enriched data with followers, images, and metadata
├── scrape_ceos.ts              # Script to scrape CEO names and Twitter URLs
├── fetch_ceo_data.ts           # Script to fetch follower counts and profile images
├── top_ceos.ts                 # Script to validate and display the top 25 CEOs
├── README.md                   # This documentation file
```

---

## Workflow

1. **Scrape CEO Data**  
   Use `scrape_ceos.ts` to scrape CEO names and Twitter URLs from the HTMX CEO website.
   ```bash
   bun scrape_ceos.ts
   ```
   **Output**: Generates `ceos.json`:
   ```json
   [
     {
       "name": "loftwah",
       "twitter": "https://twitter.com/loftwah"
     },
     ...
   ]
   ```

2. **Enrich Data**  
   Use `fetch_ceo_data.ts` to fetch Twitter profile details (followers and profile images) and save the profile images to the `images/` directory.
   ```bash
   bun fetch_ceo_data.ts
   ```
   **Output**: Generates `ceos_with_followers.json`:
   ```json
   [
     {
       "name": "loftwah",
       "twitter": "https://twitter.com/loftwah",
       "screenName": "loftwah",
       "followers": 12345,
       "imagePath": "images/loftwah.jpg"
     },
     ...
   ]
   ```
   **Downloads**: Images saved as `images/<screenName>.jpg`.

3. **Identify Top CEOs**  
   Use `top_ceos.ts` to validate and display the top 25 CEOs based on follower count.
   ```bash
   bun top_ceos.ts
   ```
   **Output**: The top 25 CEOs are displayed in the console in a readable format:
   ```plaintext
   1. loftwah (@loftwah)
      Followers: 12345
      Twitter: https://twitter.com/loftwah
      Image: images/loftwah.jpg
   ```

---

## Prerequisites

- **Bun**: Install from [https://bun.sh](https://bun.sh).
- **Playwright**: Installed automatically when running scripts.
- **SocialData API Key**: Add your API key to a `.env` file:
  ```
  SOCIALDATA_API_KEY=your_api_key_here
  ```

---

## Notes

- **images/**: Contains all downloaded Twitter profile images.
- **ceos_with_followers.json**: Includes enriched data for all CEOs.
- **Top 25 Selection**: The `top_ceos.ts` script identifies the most-followed CEOs for the tier list.
- **Graceful Handling**: Missing profiles or errors do not stop the scripts.

---
