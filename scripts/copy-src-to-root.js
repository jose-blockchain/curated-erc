#!/usr/bin/env node
/**
 * Copies published Solidity trees from src/ to package root so npm publish
 * includes them and imports like "curated-erc/token/..." / "curated-erc/auth/..."
 * resolve. Run by prepublishOnly.
 */
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const src = path.join(root, "src");
const dirs = ["token", "metatx", "finance", "utils", "auth", "agent", "diamond"];

for (const dir of dirs) {
  const from = path.join(src, dir);
  const to = path.join(root, dir);
  if (fs.existsSync(from)) {
    fs.rmSync(to, { recursive: true, force: true });
    fs.cpSync(from, to, { recursive: true });
  }
}
