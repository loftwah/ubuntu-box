import { readFile, mkdir, writeFile } from 'fs/promises';
import { existsSync } from 'fs';
import fetch from 'node-fetch'; // Bun has native fetch
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

// Fetch profile details from the SocialData API
async function fetchProfileDetails(screenName: string): Promise<{ imageUrl: string | null; followers: number | null }> {
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
      const imageUrl = data.profile_image_url_https?.replace("_normal", "_400x400") || null;
      const followers = data.followers_count || null;
      return { imageUrl, followers };
    } else {
      console.error(`Error fetching ${screenName}:`, await response.text());
      return { imageUrl: null, followers: null };
    }
  } catch (error) {
    console.error(`Failed to fetch data for ${screenName}:`, error);
    return { imageUrl: null, followers: null };
  }
}

// Download the image if it doesn't already exist
async function downloadImage(url: string, filename: string) {
  if (existsSync(filename)) {
    console.log(`Image already exists: ${filename}, skipping download.`);
    return;
  }
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

    const updatedCEOs = [];

    // Process each CEO
    for (const ceo of ceos) {
      const screenName = ceo.twitter.split("/").pop(); // Extract screen name from URL
      if (!screenName) {
        console.error(`Invalid Twitter URL for CEO: ${ceo.name}`);
        continue;
      }

      // Fetch profile details (image URL and follower count)
      const { imageUrl, followers } = await fetchProfileDetails(screenName);

      // If we got an image URL, download the image
      let imagePath = null;
      if (imageUrl) {
        imagePath = `images/${screenName}.jpg`;
        await downloadImage(imageUrl, imagePath);
      } else {
        console.error(`No profile image found for ${screenName}`);
      }

      // Add metadata to the updated list
      updatedCEOs.push({
        name: ceo.name,
        twitter: ceo.twitter,
        screenName,
        followers,
        imagePath,
      });
    }

    // Save the updated data to a new JSON file
    await writeFile("ceos_with_followers.json", JSON.stringify(updatedCEOs, null, 2), "utf-8");
    console.log("Saved updated CEO data with followers to ceos_with_followers.json");
  } catch (error) {
    console.error("Error:", error);
  }
}

main();
