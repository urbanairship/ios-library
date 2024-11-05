AIRSHIP_VERSION="18.12.1"

Pod::Spec.new do |s|
    s.version                 = AIRSHIP_VERSION
    s.name                    = "AirshipContentExtension"
    s.summary                 = "Airship iOS Content Extension"
    s.documentation_url       = "https://docs.airship.com/platform/ios"
    s.homepage                = "https://www.airship.com"
    s.license                 = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
    s.author                  = { "Airship" => "support@airship.com" }
    s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }
    s.public_header_files     = "AirshipExtensions/AirshipNotificationContentExtension/Source/Public/*.h"
    s.source_files            = ["AirshipExtensions/AirshipNotificationContentExtension/Source/**/*.{h,m}", "AirshipExtensions/AirshipNotificationContentExtension/Source/Templates/Carousel/**/*.{h,m}", "AirshipExtensions/AirshipNotificationContentExtension/Source/Public/**/*.{h,m}"]
    s.weak_frameworks         = "UserNotifications"
    s.module_name             = "AirshipContentExtension"
    s.requires_arc            = true
    s.ios.deployment_target   = "14.0"
    s.pod_target_xcconfig     = { 'DEFINES_MODULE' => 'YES' }
end
