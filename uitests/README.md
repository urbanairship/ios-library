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
  scene root (`id: thomas:root`), and screenshots. Embedded fixtures add
  `-thomasEmbeddedID` so the app pushes a bounded host view for that ID. Rendered views expose
  `thomas:<payload identifier>` accessibility identifiers for stable targeting.
- Generated flows capture the first page only. Anything interactive (paging, form input)
  is an authored flow in `flows/`; an authored flow that launches a fixture owns it, and the
  generator skips that fixture.
- In test mode the app swaps every remote image in the launched layout for a locally
  generated placeholder (1200x800, bordered, off-center disc), so image sizing, cropping and
  scaling are exercised without the network. Several fixture hosts refuse non-browser
  clients anyway, which would otherwise leave spinners in the screenshot.
- The generator skips, with the reason recorded in the manifest: animated media (video,
  YouTube, Vimeo, gif) and auto-advancing pagers (the frame lands at a random animation
  phase), web views (remote content the repo does not control), and banner fixtures whose
  placement uses a string `position` (a schema drift iOS cannot decode yet). Extra
  exclusions go under `sweep.skip` in `config.json` as `"Scenes/<Category>/<file>": "reason"`.
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
  checkout forever. Baselines are minted by CI on every push to `next` (plus a weekly
  refresh so the artifact never expires) and stored as the `baselines-<runtime>` workflow
  artifact; `uitest baseline-pull` fetches the newest one into `build/baselines/` (needs
  `gh auth login`), and `uitest diff` pulls automatically when the cache is empty. If the
  artifact cannot be fetched the PR check fails rather than passing without a comparison;
  the one exception is before the first mint on `next`, when everything reports as new.
- **PR flow.** The workflow diffs the PR's screenshots against the `next` baselines, builds
  a self-contained HTML report (baseline / this run / diff side by side), publishes it to
  the repo's private GitHub Pages site under `ui-tests/pr-<n>/` (org members only; the
  `ui-test-report` artifact holds the same file plus raw screenshots) and posts one bot
  comment with the summary and link. Reports live on the `gh-pages` branch, which is not
  mirrored to the public repo; every publish rewrites that branch as a single commit and
  removes reports for closed PRs, and a weekly job prunes as well, so nothing accumulates. An intentional visual change is accepted by adding the `visual-change-accepted`
  label, which re-runs the check in report-only mode; merging to `next` then mints the new
  baselines. PRs into `main` are skipped: that release line has no baselines of its own.
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
