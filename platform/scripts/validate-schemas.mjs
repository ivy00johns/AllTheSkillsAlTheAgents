import { readdir, readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const schemaDir = path.join(__dirname, "..", "packages", "contracts", "schemas");

const files = (await readdir(schemaDir)).filter((name) => name.endsWith(".json")).sort();

if (files.length === 0) {
  throw new Error(`No schema files found in ${schemaDir}`);
}

for (const file of files) {
  const fullPath = path.join(schemaDir, file);
  const raw = await readFile(fullPath, "utf8");
  JSON.parse(raw);
  console.log(`ok ${file}`);
}
