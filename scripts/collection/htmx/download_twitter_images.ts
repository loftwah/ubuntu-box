import { readFile, mkdir, writeFile } from 'fs/promises';
import fetch from 'node-fetch'; // Bun has native fetch, no need to install
import { existsSync } from 'fs';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const API_KEY = process.env.SOCIALDATA_API_KEY;

if (!API_KEY) {
  console.error("Missing SOCIALDATA_API_KEY in .env");
  process.exit(1);
}

// Ensure the images directory exists
async function ensureDirectoryExists(directory: string) {
  if (!existsSync(directory)) {
    await mkdir(directory, { recursive: true });
  }
}

// Fetch the profile image URL from the SocialData API
async function fetchProfileImageURL(screenName: string): Promise<string | null> {
  const url = `https://api.socialdata.tools/twitter/user/${screenName}`;
  try {
    const response = await fetch(url, {
      headers: {
        Authorization: `Bearer ${API_KEY}`,
        Accept: "application/json",
      },
    });

    if (response.ok) {
      const data = await response.json();
      return data.profile_image_url_https.replace("_normal", "_400x400"); // Use high-res image
    } else {
      console.error(`Error fetching ${screenName}:`, await response.text());
      return null;
    }
  } catch (error) {
    console.error(`Failed to fetch data for ${screenName}:`, error);
    return null;
  }
}

// Download the image and save it to the images directory
async function downloadImage(url: string, filename: string) {
  try {
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Failed to fetch image: ${url}`);
    }
    const buffer = await response.arrayBuffer();
    await writeFile(filename, Buffer.from(buffer));
    console.log(`Downloaded: ${filename}`);
  } catch (error) {
    console.error(`Error downloading ${url}:`, error);
  }
}

// Main function
async function main() {
  try {
    // Read CEOs from the JSON file
    const ceos = JSON.parse(await readFile("ceos.json", "utf-8"));

    // Ensure the images directory exists
    await ensureDirectoryExists("images");

    // Fetch and download images for each CEO
    for (const ceo of ceos) {
      const screenName = ceo.twitter.split("/").pop(); // Extract screen name from URL
      if (!screenName) {
        console.error(`Invalid Twitter URL for CEO: ${ceo.name}`);
        continue;
      }

      const profileImageURL = await fetchProfileImageURL(screenName);
      if (profileImageURL) {
        const filename = `images/${screenName}.jpg`;
        await downloadImage(profileImageURL, filename);
      } else {
        console.error(`No profile image found for ${screenName}`);
      }
    }
  } catch (error) {
    console.error("Error:", error);
  }
}

main();
