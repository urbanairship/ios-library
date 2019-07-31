AIRSHIP_VERSION="11.1.1"

Pod::Spec.new do |s|
   s.version                 = AIRSHIP_VERSION
   s.name                    = "UrbanAirship-iOS-Location"
   s.summary                 = "Airship iOS Location"

   s.documentation_url       = "https://docs.airship.com/platform/ios"
   s.homepage                = "https://www.airship.com"
   s.author                  = { "Airship" => "support@airship.com" }

   s.license                 = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
   s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }

   s.module_name             = "AirshipLocationKit"
   s.ios.deployment_target   = "10.0"
   s.requires_arc            = true

   s.source_files            = 'AirshipLocationKit/AirshipLocationKit/*.{h,m}'
   s.private_header_files    = 'AirshipLocationKit/AirshipLocationKit/*+Internal*.h'

   s.frameworks              = 'Foundation', 'CoreLocation'
   s.dependency                'UrbanAirship-iOS-SDK', AIRSHIP_VERSION
end
