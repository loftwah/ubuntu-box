import { readFile } from 'fs/promises';

// Main function
async function main() {
  try {
    // Load the CEOs data
    const ceos = JSON.parse(await readFile("ceos_with_followers.json", "utf-8"));

    // Validate structure
    if (!Array.isArray(ceos)) {
      throw new Error("Invalid data format: ceos_with_followers.json must be an array.");
    }

    // Filter CEOs with valid follower counts and sort them by follower count
    const sortedCEOs = ceos
      .filter((ceo) => typeof ceo.followers === "number") // Ensure followers are valid
      .sort((a, b) => (b.followers || 0) - (a.followers || 0)); // Sort by followers in descending order

    // Select the top 25 CEOs
    const top50CEOs = sortedCEOs.slice(0, 50);

    // Output the top 25 CEOs in a readable format
    console.log("Top 50 CEOs:\n");
    top50CEOs.forEach((ceo, index) => {
      console.log(
        `${index + 1}. ${ceo.name} (@${ceo.screenName})\n   Followers: ${ceo.followers}\n   Twitter: ${ceo.twitter}\n   Image: ${ceo.imagePath || "No image"}\n`
      );
    });
  } catch (error) {
    console.error("Error:", error);
  }
}

main();
