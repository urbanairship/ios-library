AIRSHIP_VERSION="18.6.0"

Pod::Spec.new do |s|
    s.version                 = AIRSHIP_VERSION
    s.name                    = "AirshipServiceExtension"
    s.summary                 = "Airship iOS Service Extension"
    s.documentation_url       = "https://docs.airship.com/platform/ios"
    s.homepage                = "https://www.airship.com"
    s.license                 = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
    s.author                  = { "Airship" => "support@airship.com" }
    s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }
    s.source_files            = "AirshipExtensions/AirshipNotificationServiceExtension/Source/**/*.{swift}"
    s.weak_frameworks         = "UserNotifications"
    s.module_name             = "AirshipServiceExtension"
    s.requires_arc            = true
    s.ios.deployment_target      = "14.0"
    s.watchos.deployment_target  = "7.0"
    s.swift_versions             = "5.0"
    s.pod_target_xcconfig     = { 'DEFINES_MODULE' => 'YES' }
end
