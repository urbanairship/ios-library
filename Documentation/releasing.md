# Releasing

The release runs in three stages. On a normal release, pushing the tag runs all
three in order and nothing else is needed. The stages exist separately so a
release can still go out when CI cannot build it — most often because the runner
image has not picked up the Xcode a new OS requires, which historically lags the
GM by weeks.

| Stage | Job | Needs Xcode | Produces |
|---|---|---|---|
| 1 | `create-release` | no | Draft release with the CHANGELOG notes |
| 2 | `attach-packages` | **yes** | Zips attached, release published |
| 3 | `kickoff-prebuilt` | no | `ios-library-prebuilt` release run |

## Normal release

Push the tag. `check-version` confirms the tag matches
`AirshipCore/Source/AirshipVersion.swift`, the test suite runs, and the three
stages follow.

## When the runners are behind the release Xcode

Stages 1 and 3 run on Linux and do not care about Xcode, so let CI do those.
Build stage 2 yourself.

```sh
# 1. Draft the release from CI:
#    Actions ▸ Release ▸ Run workflow ▸ version: 21.1.0, stage: create-release
#    ...or locally:
bash scripts/release_create.sh 21.1.0

# 2. Build and attach from a machine with the release Xcode and the
#    distribution certificate. This builds, uploads, and publishes.
bash scripts/release_attach.sh 21.1.0

# 3. Kick off the prebuilt repo:
#    Actions ▸ Release ▸ Run workflow ▸ version: 21.1.0, stage: kickoff-prebuilt
#    ...or locally:
bash scripts/release_prebuilt.sh 21.1.0
```

`release_attach.sh` takes `--skip-build` to upload zips already sitting in
`./build` — useful when the build succeeded but the upload did not.

## Notes

- The release is a **draft** until stage 2 attaches the assets, so it is
  invisible to anyone without push access until the zips are on it.
- The tag itself is public the moment it is pushed, and SPM resolves from tags
  rather than releases. SPM consumers can therefore pick up the version before
  the release page is visible. If stage 2 is going to lag by more than a day,
  say so wherever the release is announced.
- Stages are re-runnable. `release_create.sh` refreshes the notes on an existing
  draft and refuses to touch an already-published release; `release_attach.sh`
  uploads with `--clobber`.
- Re-running a stage from the Actions UI skips the test suite, which only gates
  the tag-push path. Stage 2 does rebuild the packages on CI, so dispatch it
  only when CI can actually build them.
