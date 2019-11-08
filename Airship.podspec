AIRSHIP_VERSION="12.0.2"

Pod::Spec.new do |s|
   s.version                 = AIRSHIP_VERSION
   s.name                    = "Airship"
   s.summary                 = "Airship iOS SDK"
   s.documentation_url       = "https://docs.airship.com/platform/ios"
   s.homepage                = "https://www.airship.com"
   s.author                  = { "Airship" => "support@airship.com" }
   s.license                 = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
   s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }
   s.module_name             = "Airship"
   s.ios.deployment_target   = "11.0"
   s.tvos.deployment_target  = "11.0"
   s.requires_arc            = true
   s.swift_version           = "5.0"
   s.default_subspecs        = ["Core"]

   s.subspec "Core" do |core|
      core.ios.resource_bundle        = { "AirshipResources" =>  ["AirshipKit/AirshipResources/common/*", "AirshipKit/AirshipResources/ios/*"] }
      core.tvos.resource_bundle       = { "AirshipResources tvOS" =>  ["AirshipKit/AirshipResources/common/*", "AirshipKit/AirshipResources/tvos/*"] }
      core.ios.exclude_files          = "AirshipKit/AirshipResources/ios/Info.plist"
      core.tvos.exclude_files         = "AirshipKit/AirshipResources/tvos/Info.plist"
      core.ios.source_files           = "AirshipKit/AirshipKit/ios/*.{h,m,mm}", "AirshipKit/AirshipKit/common/*.{h,m,mm}"
      core.tvos.source_files          = "AirshipKit/AirshipKit/tvos/*.{h,m,mm}", "AirshipKit/AirshipKit/common/*.{h,m,mm}"
      core.ios.private_header_files   = "AirshipKit/AirshipKit/common/*+Internal*.h","AirshipKit/AirshipKit/ios/*+Internal*.h"
      core.tvos.private_header_files  = "AirshipKit/AirshipKit/common/*+Internal*.h","AirshipKit/AirshipKit/tvos/*+Internal*.h"
      core.libraries                  = "z", "sqlite3"
      core.frameworks                 = "UserNotifications", "CFNetwork", "CoreGraphics", "Foundation", "MobileCoreServices", "Security", "SystemConfiguration", "UIKit", "CoreData", "StoreKit"
      core.ios.frameworks             = "WebKit", "CoreTelephony"
   end

   s.subspec "Location" do |location|
      location.source_files           = "AirshipLocationKit/AirshipLocationKit/*.{h,m}"
      location.private_header_files   = "AirshipLocationKit/AirshipLocationKit/*+Internal*.h"
      location.frameworks             = "Foundation", "CoreLocation"
      location.dependency               "Airship/Core"
   end

   # s.subspec "Debug" do |debug|
   #    debug.platform                  = "ios"
   #    debug.source_files              = [ "AirshipDebugKit/AirshipDebugKit/**/*.{h,m,swift}" ]
   #    debug.resources                 = ["AirshipDebugKit/AirshipDebugKit/**/*storyboard", "AirshipDebugKit/AirshipDebugKit/Resources/**" ]
   #    debug.frameworks                = "UIKit"
   #    debug.dependency                  "Airship/Core"
   # end
end
