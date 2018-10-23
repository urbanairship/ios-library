Pod::Spec.new do |s|
    s.version                 = "10.0.3"

    s.name                    = "UrbanAirship-iOS-AppExtensions"
    s.summary                 = "Urban Airship iOS App Extensions"
    s.documentation_url       = "http://docs.urbanairship.com/platform/ios.html"
    s.homepage                = "https://www.urbanairship.com"
    s.license                 = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
    s.author                  = { "Urban Airship" => "support@urbanairship.com" }
    s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }

    s.module_name = "AirshipAppExtensions"
    s.requires_arc = true
    s.ios.deployment_target   = "10.0"
    s.ios.source_files      = 'AirshipAppExtensions/AirshipAppExtensions/*.{h,m,mm}'
    s.ios.weak_frameworks = 'UserNotifications'
end
