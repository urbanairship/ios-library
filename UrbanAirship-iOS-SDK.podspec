Pod::Spec.new do |s|
   s.version                 = "8.3.3"
   s.name                    = "UrbanAirship-iOS-SDK"
   s.summary                 = "Urban Airship iOS SDK"

   s.documentation_url       = "http://docs.urbanairship.com/platform/ios.html"
   s.homepage                = "https://www.urbanairship.com"
   s.author                  = { "Urban Airship" => "support@urbanairship.com" }

   s.license                 = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
   s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }

   s.module_name             = "AirshipKit"
   s.ios.deployment_target   = "8.0"
   s.requires_arc            = true

   s.resource_bundle         = { 'AirshipResources' =>  ['AirshipKit/AirshipResources/*'] }
   s.source_files            = 'AirshipKit/AirshipKit/common/*.{h,m,mm}'
   s.ios.source_files        = 'AirshipKit/AirshipKit/ios/*.{h,m,mm}'
   s.private_header_files    = 'AirshipKit/AirshipKit/*/*+Internal*.h', 'AirshipKit/AirshipKit/common/AirshipKit.h', 'AirshipKit/AirshipKit/common/AirshipLib.h'

   s.libraries               = 'z', 'sqlite3'
   s.frameworks              = 'UserNotifications', 'CFNetwork', 'CoreGraphics', 'Foundation', 'MobileCoreServices', 'Security', 'SystemConfiguration', 'UIKit', 'CoreTelephony', 'CoreLocation', 'CoreData'
end
