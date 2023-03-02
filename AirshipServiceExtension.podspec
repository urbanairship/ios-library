AIRSHIP_VERSION="16.11.2"

Pod::Spec.new do |s|
    s.version                 = AIRSHIP_VERSION
    s.name                    = "AirshipServiceExtension"
    s.summary                 = "Airship iOS Service Extension"
    s.documentation_url       = "https://docs.airship.com/platform/ios"
    s.homepage                = "https://www.airship.com"
    s.license                 = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
    s.author                  = { "Airship" => "support@airship.com" }
    s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }
    s.source_files            = "AirshipExtensions/AirshipNotificationServiceExtension/Source/**/*.{h,m}"
    s.weak_frameworks         = "UserNotifications"
    s.module_name             = "AirshipServiceExtension"
    s.requires_arc            = true
    s.ios.deployment_target   = "11.0"
end
