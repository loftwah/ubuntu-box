import { chromium } from 'playwright';
import { writeFile } from 'fs/promises';

// Define the CEO structure
interface CEO {
  name: string;
  twitter: string;
}

(async () => {
  // Launch browser
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();

  try {
    // Navigate to the HTMX CEO website
    await page.goto('https://htmx.ceo/');

    // Wait for the CEO container to load
    await page.waitForSelector('#ceo-container');

    // Extract CEO names and Twitter links
    const ceos: CEO[] = await page.evaluate(() => {
      const ceoElements = document.querySelectorAll('#ceo-container a');
      return Array.from(ceoElements).map(ceo => ({
        name: ceo.textContent?.trim() || '',
        twitter: ceo.href
      }));
    });

    // Log the results (for debugging)
    console.log(ceos);

    // Save to a JSON file
    await writeFile('ceos.json', JSON.stringify(ceos, null, 2), 'utf-8');
    console.log('CEOs data saved to ceos.json');
  } catch (error) {
    console.error('Error scraping HTMX CEOs:', error);
  } finally {
    // Close browser
    await browser.close();
  }
})();
