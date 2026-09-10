#!/usr/bin/env node
// Generates one Maestro flow per Thomas scene fixture so the whole thomas-layouts set is
// screenshotted, not a hand-picked few. Output goes to a build directory (never committed):
// fixtures arrive via fetch-layouts, so a layouts.version bump changes coverage on its own.
//
//   node generate-flows.js <out-dir>
//
// Every fixture gets a launch + wait-for-root + screenshot flow, except:
//   - fixtures a flow in flows/ already opens (authored flows own their fixture)
//   - animated media (video, YouTube, Vimeo, gif) and auto-advancing pagers: the frame
//     lands at a random animation phase, so the pixel diff is noise
//   - web views: remote content the repo does not control
//   - banners whose placement uses a string position (a schema drift iOS cannot decode yet)
//   - anything listed under sweep.skip in config.json, with the reason given there
// Pagers are captured on their first page only; per-page flows are authored by hand.
// Authored flows are copied alongside so one `maestro test <out-dir>` runs everything, and
// manifest.json records what was generated, authored and skipped (the report shows it).

const fs = require("fs");
const path = require("path");
const YAML = require("yaml");

const uitestsDir = path.resolve(__dirname, "..");
const repoRoot = path.resolve(uitestsDir, "..");
const config = JSON.parse(fs.readFileSync(path.join(uitestsDir, "config.json"), "utf8"));
const outDir = process.argv[2];
if (!outDir) {
  console.error("usage: generate-flows.js <out-dir>");
  process.exit(2);
}

const appId = config.ios.appId;
const fixturesRoot = path.join(repoRoot, config.sweep.fixtures);
const authoredDir = path.join(uitestsDir, "flows");
const settleMs = config.sweep.mediaSettleMs;
const manualSkips = config.sweep.skip || {};
const categories = ["Modal", "Banner", "Embedded"];
const animatedMedia = new Set(["video", "youtube", "vimeo"]);

// Walks a fixture and records what would make its screenshot non-deterministic.
function inspect(node, facts) {
  if (Array.isArray(node)) {
    node.forEach((child) => inspect(child, facts));
    return;
  }
  if (!node || typeof node !== "object") return;
  if (node.type === "media") {
    const kind = String(node.media_type || "");
    const url = String(node.url || "").split("?")[0].toLowerCase();
    if (animatedMedia.has(kind) || url.endsWith(".gif")) facts.animated = true;
    else facts.media = true;
  }
  if (node.type === "web_view") facts.webView = true;
  if (node.automated_actions) facts.autoAdvance = true;
  Object.values(node).forEach((child) => inspect(child, facts));
}

function skipReason(category, doc, facts) {
  if (doc?.presentation?.type === "banner" && typeof doc?.presentation?.default_placement?.position === "string") {
    return "banner position is a string (known iOS decode gap)";
  }
  if (facts.animated) return "animated media";
  if (facts.autoAdvance) return "auto-advancing pager";
  if (facts.webView) return "remote web content";
  return null;
}

// Fixtures that an authored flow already launches.
function authoredFixtures() {
  const owned = new Map();
  for (const file of fs.readdirSync(authoredDir).filter((f) => /\.ya?ml$/.test(f)).sort()) {
    const text = fs.readFileSync(path.join(authoredDir, file), "utf8");
    for (const doc of YAML.parseAllDocuments(text)) {
      const commands = doc.toJS();
      if (!Array.isArray(commands)) continue;
      for (const command of commands) {
        const fixture = command?.launchApp?.arguments?.thomasLayout;
        if (typeof fixture === "string") owned.set(fixture, file);
      }
    }
  }
  return owned;
}

// "Scenes/Embedded/100pct x auto.yml" -> "embedded__100pct_x_auto"
function flowName(category, file) {
  const stem = file.replace(/\.ya?ml$/, "").replace(/\s+/g, "_");
  if (!/^[A-Za-z0-9._-]+$/.test(stem)) {
    throw new Error(`fixture name has characters a screenshot file name cannot carry: ${file}`);
  }
  return `${category.toLowerCase()}__${stem}`;
}

function flowText(name, fixture, embeddedID, waitForMedia) {
  const args = { uiTestMode: true, thomasLayout: fixture };
  if (embeddedID) args.thomasEmbeddedID = embeddedID;
  const commands = [
    { launchApp: { clearState: true, arguments: args } },
    { extendedWaitUntil: { visible: { id: "thomas:root" }, timeout: 15000 } },
    "waitForAnimationToEnd",
  ];
  if (waitForMedia) {
    // Maestro has no sleep: waiting for an element that never appears, marked optional,
    // gives remote images a moment to load without failing the flow.
    commands.push({
      extendedWaitUntil: { visible: { id: "uitest:media-settle" }, timeout: settleMs, optional: true },
    });
  }
  commands.push({ takeScreenshot: `${name}__p0` });
  return (
    `# Generated from ${fixture} by uitests/tools/generate-flows.js - edit the generator, not this file.\n` +
    `appId: ${appId}\n---\n` +
    YAML.stringify(commands)
  );
}

fs.rmSync(outDir, { recursive: true, force: true });
fs.mkdirSync(outDir, { recursive: true });

const owned = authoredFixtures();
const manifest = { fixtures: 0, generated: [], authored: [], skipped: [] };
const names = new Set();

for (const category of categories) {
  const dir = path.join(fixturesRoot, category);
  if (!fs.existsSync(dir)) continue;
  for (const file of fs.readdirSync(dir).filter((f) => /\.ya?ml$/.test(f)).sort()) {
    const fixture = `Scenes/${category}/${file}`;
    manifest.fixtures += 1;
    const skip = (reason) => manifest.skipped.push({ fixture, reason });

    if (owned.has(fixture)) {
      manifest.authored.push({ flow: owned.get(fixture), fixture });
      continue;
    }
    if (manualSkips[fixture]) {
      skip(manualSkips[fixture]);
      continue;
    }
    let doc;
    try {
      doc = YAML.parse(fs.readFileSync(path.join(dir, file), "utf8"));
    } catch (error) {
      skip(`fixture does not parse: ${error.message.split("\n")[0]}`);
      continue;
    }
    const facts = {};
    inspect(doc, facts);
    const reason = skipReason(category, doc, facts);
    if (reason) {
      skip(reason);
      continue;
    }
    const embeddedID = category === "Embedded" ? doc?.presentation?.embedded_id : null;
    if (category === "Embedded" && typeof embeddedID !== "string") {
      skip("embedded fixture has no presentation.embedded_id");
      continue;
    }

    const name = flowName(category, file);
    if (names.has(name)) throw new Error(`two fixtures map to the same flow name: ${name}`);
    names.add(name);
    fs.writeFileSync(path.join(outDir, `${name}.yaml`), flowText(name, fixture, embeddedID, !!facts.media));
    manifest.generated.push({ flow: `${name}.yaml`, fixture });
  }
}

// Authored flows run from the same directory; those without a fixture (DevApp chrome
// canaries) are listed too so the manifest is the full picture.
for (const file of fs.readdirSync(authoredDir).filter((f) => /\.ya?ml$/.test(f)).sort()) {
  fs.copyFileSync(path.join(authoredDir, file), path.join(outDir, file));
  if (!manifest.authored.some((entry) => entry.flow === file)) {
    manifest.authored.push({ flow: file, fixture: null });
  }
}

fs.writeFileSync(path.join(outDir, "manifest.json"), JSON.stringify(manifest, null, 2) + "\n");

const byReason = {};
for (const { reason } of manifest.skipped) byReason[reason] = (byReason[reason] || 0) + 1;
console.log(
  `flows: ${manifest.generated.length} generated + ${manifest.authored.length} authored ` +
    `-> ${outDir}\nfixtures: ${manifest.fixtures}, skipped ${manifest.skipped.length}` +
    Object.entries(byReason).map(([reason, n]) => `\n  ${n}\t${reason}`).join("")
);
