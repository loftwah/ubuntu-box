import { readFile, writeFile, readdir, unlink } from "fs/promises";

// Delete unwanted images
async function deleteUnwantedImages(keepImages: string[]) {
  try {
    const allImages = await readdir("images");
    for (const image of allImages) {
      const imagePath = `images/${image}`;
      if (!keepImages.includes(imagePath)) {
        await unlink(imagePath);
        console.log(`Deleted: ${imagePath}`);
      }
    }
  } catch (error) {
    console.error("Error deleting images:", error);
  }
}

// Main function
async function main() {
  try {
    // Load existing CEO data
    const ceos = JSON.parse(await readFile("ceos_with_followers.json", "utf-8"));

    // Sort by followers and get the top 50
    const top50CEOs = ceos
      .filter((ceo) => ceo.followers !== null)
      .sort((a, b) => (b.followers ?? 0) - (a.followers ?? 0))
      .slice(0, 50);

    // Get the image paths for the top 50
    const keepImages = top50CEOs.map((ceo) => ceo.imagePath).filter(Boolean);

    // Delete all other images
    await deleteUnwantedImages(keepImages);

    // Save the top 50 to a new JSON file
    await writeFile(
      "ceos_with_followers_top50.json",
      JSON.stringify(top50CEOs, null, 2),
      "utf-8"
    );
    console.log("Saved top 50 CEO data to ceos_with_followers_top50.json");
  } catch (error) {
    console.error("Error:", error);
  }
}

main();
