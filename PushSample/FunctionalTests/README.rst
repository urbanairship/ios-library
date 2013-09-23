Use the PushSampleKIFTests target.

You can run these on a real device from the command line using xcodebuild with the 'test' buildaction.

For example, to run the PushSampleKIFTests on the iPod:
xcodebuild -destination "name=iPod" -project PushSampleLib.xcodeproj -scheme PushSampleKIFTests test

