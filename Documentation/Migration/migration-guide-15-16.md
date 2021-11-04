# Airship iOS SDK Migration Guide

**Due to a bug that mishandles persisted SDK settings, apps should migrate to 16.0.2 or newer**

# Airship SDK 15.x to 16.0.2

The only breaking change in SDK 16.0 is the CocoaPods import has been updated from `Airship` to `AirshipKit`

```
// 15.x
import Airship

// 16.x
import AirshipKit
```

This is to avoid the class `Airship` from conflicting with the framework `Airship` to make it possible to use resolve any name conflicts with other frameworks.

