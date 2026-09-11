# Thomas Scene UI Tests

Maestro-driven screenshot tests for Thomas scenes, run against the DevApp on a pinned
iOS simulator. The same entry point runs locally and in CI (`thomas-ui-tests.yml`).

## Quick start

```sh
make uitest-doctor    # verify toolchain (maestro, java, node, pinned iOS runtime)
npm --prefix uitests install
make uitest-run       # build, boot the test sim, run flows, diff vs the `next` baselines, report
open uitests/build/report/index.html
```

Individual steps via `uitests/bin/uitest`: `build`, `boot-sim`, `install`, `generate`,
`run-flows [dir]`, `baseline-pull`, `diff`, `report`, `set-baseline`, `mint`, `shutdown`.

## How it works

- Every scene fixture under `DevApp/Dev App/Thomas/Resources/Scenes` (the pinned
  thomas-layouts checkout, see `layouts.version`) gets a flow. `uitest generate`
  (`tools/generate-flows.js`) writes one per fixture into `build/flows/`, alongside the
  hand-written flows from `flows/`, and `run-flows` runs that directory. Generated flows are
  never committed: a `layouts.version` bump changes coverage by itself, and the run's
  `manifest.json` (surfaced in the report) lists what was captured and what was skipped, with
  the reason. Screenshots are named `<category>__<fixture stem>__p<page>.png`.
- A flow launches the DevApp with `-thomasLayout <Scenes|Messages>/<Category>/<file>` and
  `-uiTestMode true` (see `UITestLaunch` in `DevApp/Dev App/MainApp.swift`), waits for the
  scene root (`id: thomas:root`), and screenshots. Launch arguments must be quoted strings
  in the flow YAML (`uiTestMode: "true"`): Maestro passes a bare boolean to iOS without the
  leading dash, `UserDefaults` never sees it, and the app silently runs without test mode.
  The generator rejects boolean arguments in authored flows for that reason. Embedded fixtures add
  `-thomasEmbeddedID` so the app pushes a bounded host view for that ID. Rendered views expose
  `thomas:<payload identifier>` accessibility identifiers for stable targeting.
- Generated flows capture the first page only. Anything interactive (paging, form input)
  is an authored flow in `flows/`; an authored flow that launches a fixture owns it, and the
  generator skips that fixture.
- In test mode the app stubs whatever would make a frame non-deterministic (see
  `stubbingRemoteContent` in `DevApp/Dev App/Thomas/Layouts.swift`): every remote image
  becomes a locally generated placeholder (1200x800, bordered, off-center disc), so sizing,
  cropping and scaling are exercised without the network; video, YouTube and Vimeo media
  become that placeholder image; web views show an inline placeholder page; pager
  automated actions are dropped so stories hold their first page; and `randomize_children`
  is turned off so option order is stable. The manifest records which
  stubs each fixture relied on and the report shows it, so a green screenshot never claims
  more than it exercised.
- The generator skips, with the reason recorded in the manifest, banner fixtures whose
  placement uses a string `position` (a schema drift iOS cannot decode yet) and anything
  under `sweep.skip` in `config.json` (`"Scenes/<Category>/<file>": "reason"`).
- The fixtures directory holds the fetched thomas-layouts scenes plus a handful of scenes
  the DevApp tracks in git itself (the Truck Finder AI demo, the embedded sizing cases).
  `fetch-layouts` keeps the tracked ones when it refetches, so every run, cached or not,
  sees the same set.
- The status bar is masked out of the diff (`diff.ignoreRegions` in `config.json`): its
  text flips between black and white depending on which window iOS consults first, a race
  the screenshots cannot control.
- Screenshots land in `build/shots/`; `uitest diff` compares them against
  `build/baselines/<runtime>/` with odiff and writes heatmaps to `build/diffs/`;
  `uitest report` turns the result into `build/report/index.html`.
- The device, OS runtime, thresholds, and exact Maestro version are pinned in `config.json`.
  Pinned on purpose: a floating "latest" (runtime or Maestro) silently shifts baselines.
- No Airship credentials are needed: the build materializes a syntactically valid dummy
  app key, which is enough for takeOff and scene display offline.

## Baselines and reports

- **Nothing image-shaped is committed.** The public `ios-library` repo is a mirror of this one
  and SPM users clone it in full, so baseline PNGs in git would land in every customer
  checkout forever. Baselines are minted by CI on every push to `next` and `main` (plus a
  weekly refresh so the artifacts never expire) and stored as the `baselines-<runtime>`
  workflow artifact of that branch's run; `uitest baseline-pull` fetches the newest one into
  `build/baselines/` (needs `gh auth login`; `UITEST_BASELINE_BRANCH` picks the branch,
  falling back to `next` for a branch that was never minted), and `uitest diff` pulls
  automatically when the cache is empty. If the artifact cannot be fetched the PR check
  fails rather than passing without a comparison; the one exception is before the first
  mint, when everything reports as new. A pull that finds the mint still running waits for
  it rather than failing.
- **PR flow.** The workflow diffs the PR's screenshots against its base branch's baselines, builds
  a gallery report (every screenshot as a card, filter by status, a viewer that flips between
  baseline / this run / diff; images are half-width WebP so a full sweep stays a few MB, the
  full-size PNGs live in the `ui-test-report` artifact), publishes it to the repo's private
  GitHub Pages site under `ui-tests/pr-<n>/` (org members only) and posts one bot comment
  with the summary and link. Reports live on the `gh-pages` branch, which is not
  mirrored to the public repo; every publish rewrites that branch as a single commit and
  removes reports for closed PRs, and a weekly job prunes as well, so nothing accumulates. An intentional visual change is accepted by adding the `visual-change-accepted`
  label, which re-runs the check in report-only mode; merging then mints the new baselines
  on the base branch.
- **Local iteration.** `uitest set-baseline` promotes the current screenshots into the local
  cache so you can diff your own change against itself while iterating. It is never
  committed. `provenance.json` next to any baseline set records the toolchain, commit,
  and time it was captured.
- What the pixel diff catches: geometry shifts, missing or moved elements, strong color
  changes (any single pixel over the per-pixel color threshold fails). What it can miss:
  uniform subtle changes below the per-pixel threshold, such as a slightly wrong shade or
  a dimmer-alpha nudge, since there is no aggregate floor. A green run means "no pixel
  moved past threshold", not "pixel-perfect".
- Authored flow rules: never leave a text field focused (cursor blink) and keep away from
  perpetually animating content, or the screenshot lands at a random animation phase.
  Scrollable fixtures are only captured at the top viewport unless the flow scrolls and takes
  extra screenshots.
- Modal screenshots include the DevApp screen behind the modal shade, so DevApp UI changes
  churn baselines too (the workflow's path filter covers `DevApp/**` for this reason).
- On a machine without the pinned runtime, iterate with an override, e.g.
  `UITEST_RUNTIME=com.apple.CoreSimulator.SimRuntime.iOS-26-5 uitests/bin/uitest run`.
  Baselines are stored per runtime; only the pinned runtime's set is canonical.

## Known issues

- All `Scenes/Banner` fixtures currently fail to decode on iOS
  (`presentation.default_placement.position` is a string like `bottom`, while
  `ThomasEdgePosition` expects `{horizontal, vertical}`); the generator skips them until
  that is resolved, at which point they are picked up automatically.
- Four modal fixtures (`nps`, `pager-fullsize`, `safe-areas-pager-forms`,
  `safe-areas-pager-remote`) fail to decode on iOS as well and are listed under
  `sweep.skip` in `config.json`; remove an entry once its fixture decodes.
- If Maestro reports "iOS driver not ready in time", cold-boot the test simulator
  (`uitest boot-sim`); reinstalling over a live simulator can wedge the driver.
