# Airship iOS SDK Migration Guide

# Airship SDK 15.x to 16.0

The only breaking change in SDK 16.0 is the CocoaPods import has been updated from `Airship` to `AirshipKit`

```
// 15.x
import Airship

// 16.x
import AirshipKit
```

This is to avoid the class `Airship` from conflicting with the framework `Airship` to make it possible to use resolve any name conflicts with other frameworks.

