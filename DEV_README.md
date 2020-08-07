# iOS Developer Readme

Notes for the Airship Mobile team.

## Pod install
To install CocoaPods, run `bundle exec pod install`. If the install fails because pods are missing, run `bundle install` and then re-run `bundle exec pod install`.

## Deploying

The release deploy will trigger automatically when pushing a version (#.#.#) tag to ios-library.
It will automatically do the following:
 - CI & Build SDK
 - Deploy the Airship.zip (xcframeworks) and Airship.framework.zip (carthage) to Github as a new Release
 - Deploy the Airship.zip (xcframeworks) to Bintray
 - Publish Pods
 - Upload the documentation to a GCS bucket that extdocs will pull from when it deploys Airship docs

### Deploy Secrets

Secrets needed to be setup for the Github Action to run:
- BINTRAY_AUTH:  <username>:<apiKey>
- COCOAPODS_TRUNK_TOKEN: The password in ~/.netrc for trunk.cocoapods.org after you authenticate with Cocoapods
- SLACK_WEBHOOK: Webhook to slack build updates.




