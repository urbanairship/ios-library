AIRSHIP_VERSION="12.0.2"

Pod::Spec.new do |s|
    s.deprecated_in_favor_of  = "AirshipExtensions"
    s.version                 = AIRSHIP_VERSION
    s.name                    = "UrbanAirship-iOS-AppExtensions"
    s.summary                 = "Airship iOS App Extensions"
    s.documentation_url       = "https://docs.airship.com/platform/ios"
    s.homepage                = "https://www.airship.com"
    s.license                 = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
    s.author                  = { "Airship" => "support@airship.com" }
    s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }

    s.module_name = "AirshipAppExtensions"
    s.requires_arc = true
    s.ios.deployment_target   = "11.0"
    s.ios.source_files      = 'AirshipAppExtensions/AirshipAppExtensions/*.{h,m,mm}'
    s.ios.weak_frameworks = 'UserNotifications'
end
