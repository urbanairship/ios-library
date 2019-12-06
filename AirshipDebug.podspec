AIRSHIP_VERSION="13.0.0"

Pod::Spec.new do |s|
   s.version                 = AIRSHIP_VERSION
   s.name                    = "AirshipDebug"
   s.summary                 = "Airship iOS SDK Debug Library"
   s.documentation_url       = "https://docs.airship.com/platform/ios"
   s.homepage                = "https://www.airship.com"
   s.author                  = { "Airship" => "support@airship.com" }

   s.license                 = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
   s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }

   s.module_name             = "AirshipDebug"
   s.ios.deployment_target   = "11.0"
   s.requires_arc            = true
   s.swift_version           = "5.0"
   s.source_files            = "Airship/AirshipDebug/Source/**/*.{h,m,swift}"
   s.resources               = "Airship/AirshipDebug/Resources/**/*"
   s.frameworks              = 'UIKit'
   s.dependency                'Airship', AIRSHIP_VERSION
   s.dependency                "Airship/Location", AIRSHIP_VERSION
end
