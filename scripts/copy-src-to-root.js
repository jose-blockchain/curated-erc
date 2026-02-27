#!/usr/bin/env node
/**
 * Copies src/token, src/metatx, src/finance, src/utils to package root
 * so that npm publish includes them and imports like "curated-erc/token/..."
 * resolve. Run by prepublishOnly.
 */
const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");
const src = path.join(root, "src");
const dirs = ["token", "metatx", "finance", "utils"];

for (const dir of dirs) {
  const from = path.join(src, dir);
  const to = path.join(root, dir);
  if (fs.existsSync(from)) {
    fs.rmSync(to, { recursive: true, force: true });
    fs.cpSync(from, to, { recursive: true });
  }
}
