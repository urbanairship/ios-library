AIRSHIP_VERSION="13.0.0"

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
   s.default_subspecs        = ["Core", "Automation", "MessageCenter"]

   s.subspec "Core" do |core|
      core.ios.resources              = "Airship/AirshipCore/Resources/common/**/*", "Airship/AirshipCore/Resources/ios/**/*"
      core.tvos.resources             = "Airship/AirshipCore/Resources/common/**/*", "Airship/AirshipCore/Resources/tvos/**/*"
      core.ios.exclude_files          = "Airship/AirshipCore/Resources/ios/Info.plist"
      core.tvos.exclude_files         = "Airship/AirshipCore/Resources/tvos/Info.plist"
      core.ios.source_files           = "Airship/AirshipCore/Source/ios/**/*.{h,m,mm}", "Airship/AirshipCore/Source/common/**/*.{h,m,mm}"
      core.tvos.source_files          = "Airship/AirshipCore/Source/tvos/**/*.{h,m,mm}", "Airship/AirshipCore/Source/common/**/*.{h,m,mm}"
      core.ios.private_header_files   = "Airship/AirshipCore/Source/common/**/*+Internal*.h", "Airship/AirshipCore/Source/ios/**/*+Internal*.h"
      core.tvos.private_header_files  = "Airship/AirshipCore/Source/common/**/*+Internal*.h", "Airship/AirshipCore/Source/tvos/**/*+Internal*.h"
      core.libraries                  = "z", "sqlite3"
      core.frameworks                 = "UserNotifications", "CFNetwork", "CoreGraphics", "Foundation", "MobileCoreServices", "Security", "SystemConfiguration", "UIKit", "CoreData", "StoreKit"
      core.ios.frameworks             = "WebKit", "CoreTelephony"
   end

   s.subspec "Location" do |location|
      location.ios.source_files           = "Airship/AirshipLocation/Source/*.{h,m}"
      location.ios.private_header_files   = "Airship/AirshipLocation/Source/*+Internal*.h"
      location.ios.frameworks             = "CoreLocation"
      location.dependency                  "Airship/Core"

   end

   s.subspec "Automation" do |automation|
      automation.ios.source_files              = "Airship/AirshipAutomation/Source/**/*.{h,m,swift}"
      automation.ios.resources                 = "Airship/AirshipAutomation/Resources/**/*"
      automation.ios.frameworks                = "UIKit"
      automation.dependency                    "Airship/Core"
   end

   s.subspec "MessageCenter" do |messageCenter|
      messageCenter.ios.source_files          = "Airship/AirshipMessageCenter/Source/**/*.{h,m,swift}"
      messageCenter.ios.private_header_files  = "Airship/AirshipMessageCenter/Source/**/*+Internal*.h"
      messageCenter.ios.resources             = "Airship/AirshipMessageCenter/Resources/**/*"
      messageCenter.dependency                  "Airship/Core"
   end

   s.subspec "Debug" do |debug|
      debug.platform                  = "ios"
      debug.source_files              = "Airship/AirshipDebug/Source/**/*.{h,m,swift}"
      debug.resources                 = "Airship/AirshipDebug/Resources/**/*"
      debug.dependency                "Airship/Core"
      debug.dependency                "Airship/Automation"
      debug.dependency                "Airship/MessageCenter"
      debug.dependency                "Airship/Location"
   end
end
