# DevApp Thomas Layouts

The DevApp's "Layout Viewer" browses two kinds of Thomas fixtures, which are
sourced differently:

- **Scenes** (`Resources/Scenes/{Modal,Banner,Embedded}`) — **not** stored in
  this repo. They are fetched from the shared, web-maintained
  [`urbanairship/thomas-layouts`](https://github.com/urbanairship/thomas-layouts)
  repo at a **pinned commit**, remapping its top-level `modal/`, `banner/` and
  `embedded/` directories into `Scenes/`.
- **Messages** (`Resources/Messages/{Modal,Banner,Fullscreen,HTML}`) — the
  in-app message fixtures are **tracked directly in this repo**. The shared repo
  does not contain message fixtures.

Related files:

- Pinned Scene version: [`../../../layouts.version`](../../../layouts.version) (repo root)
- Fetch script: [`../../../scripts/fetch-layouts.sh`](../../../scripts/fetch-layouts.sh)

## Getting the scenes

From the repo root:

```sh
make fetch-layouts
```

This clones the pinned commit from `thomas-layouts` and populates
`Resources/Scenes`. It's also run automatically as a prerequisite of
`make build-sample-ios` / `make build-sample-macos`, so a normal
`make build-samples` fetches for you. Messages are already present (tracked), so
you can build and run the DevApp in Xcode as usual.

## If you don't fetch

The DevApp **still builds** without the scenes — you'll just get an empty Scene
list and a build warning ("Thomas Scene fixtures not found. Run
`make fetch-layouts`..."). Messages are unaffected. Access to the shared repo is
never required to build.

## Updating to newer scenes

1. Bump the commit SHA in [`layouts.version`](../../../layouts.version) (repo
   root) to a newer commit from `thomas-layouts`. (The web repo publishes no
   tags, so a full commit SHA is used.)
2. Run `make fetch-layouts` again.
3. Commit the `layouts.version` change (this is the explicit, reviewable
   "update the scenes" change).

## Adding or editing fixtures

- **Scenes:** don't add them here — they're git-ignored and would be overwritten
  by the next fetch. They live in `thomas-layouts`; bump `layouts.version` to
  pick up changes.
- **Messages:** these are tracked in this repo, so add/edit them under
  `Resources/Messages` and commit normally.

## Notes

- `Resources/Scenes` is an Xcode folder reference, so the directory must always
  exist. It keeps a tracked `.gitkeep`; its fetched contents are git-ignored.
- CI authenticates to the (private) shared repo with a short-lived token minted
  from the "Airship Actions Repository Reader" GitHub App (see the workflows).
  Local builds use your normal git credentials.
- The `JurassicPark.otf` font and `SharedAssets.xcassets` are **not** part of the
  shared scenes and remain in this repo.
