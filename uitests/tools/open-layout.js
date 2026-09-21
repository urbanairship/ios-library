#!/usr/bin/env node
// Resolves a fixture argument for `uitest open` and prints what the launch needs:
// the app's `-thomasLayout` path, and the `-thomasEmbeddedID` an Embedded fixture
// requires (see UITestLaunch in MainApp.swift). Fixture listing and embedded-ID
// extraction come from fixtures.js, shared with generate-flows.js.
//
//   node open-layout.js <fixture>
//
// <fixture> is matched, in order: an exact "Scenes/<Category>/<file>" path; a bare
// filename unique across categories; or a case-insensitive substring unique across
// every fixture. Ambiguous or missing matches exit 1 with the candidates listed.

const fs = require("fs");
const path = require("path");
const YAML = require("yaml");
const { fixturesRoot, listFixtures, embeddedIDFor } = require("./fixtures");

const uitestsDir = path.resolve(__dirname, "..");
const repoRoot = path.resolve(uitestsDir, "..");
const config = JSON.parse(fs.readFileSync(path.join(uitestsDir, "config.json"), "utf8"));

const query = process.argv[2];
if (!query) {
  console.error("usage: open-layout.js <fixture>");
  process.exit(2);
}

const all = listFixtures(config, repoRoot);

function fail(message, candidates) {
  console.error(message);
  for (const c of candidates) console.error(`  ${c.fixture}`);
  process.exit(1);
}

let matches = all.filter((f) => f.fixture === query);
if (matches.length === 0) matches = all.filter((f) => f.file === query);
if (matches.length === 0) {
  const needle = query.toLowerCase();
  matches = all.filter((f) => f.fixture.toLowerCase().includes(needle));
}
if (matches.length === 0) fail(`no fixture matches "${query}"`, []);
if (matches.length > 1) fail(`"${query}" matches more than one fixture:`, matches);

const match = matches[0];
const doc = YAML.parse(fs.readFileSync(path.join(fixturesRoot(config, repoRoot), match.category, match.file), "utf8"));
const embeddedID = embeddedIDFor(match.category, doc);
if (match.category === "Embedded" && !embeddedID) {
  fail(`${match.fixture}: Embedded fixture has no presentation.embedded_id`, []);
}

console.log(JSON.stringify({ fixture: match.fixture, embeddedID }));
