// Shared fixture lookup for generate-flows.js (the full sweep) and open-layout.js
// (uitest open, one fixture at a time). Both need the same answer to "what Thomas
// scene fixtures exist" and "what embedded_id does this one need" - keep it in one
// place so they can't drift.

const fs = require("fs");
const path = require("path");

const CATEGORIES = ["Modal", "Banner", "Embedded"];

function fixturesRoot(config, repoRoot) {
  return path.join(repoRoot, config.sweep.fixtures);
}

// Every fixture under Modal/Banner/Embedded, category order then filename order -
// the order generate-flows.js has always walked them in.
function listFixtures(config, repoRoot) {
  const root = fixturesRoot(config, repoRoot);
  const fixtures = [];
  for (const category of CATEGORIES) {
    const dir = path.join(root, category);
    if (!fs.existsSync(dir)) continue;
    for (const file of fs.readdirSync(dir).filter((f) => /\.ya?ml$/.test(f)).sort()) {
      fixtures.push({ category, file, fixture: `Scenes/${category}/${file}` });
    }
  }
  return fixtures;
}

// The `-thomasEmbeddedID` an Embedded fixture's doc requires, or null for every
// other category (Modal/Banner scenes overlay directly; see MainApp.swift).
function embeddedIDFor(category, doc) {
  if (category !== "Embedded") return null;
  const id = doc?.presentation?.embedded_id;
  return typeof id === "string" ? id : null;
}

module.exports = { CATEGORIES, fixturesRoot, listFixtures, embeddedIDFor };
