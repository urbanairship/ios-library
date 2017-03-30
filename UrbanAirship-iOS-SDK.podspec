Pod::Spec.new do |s|
   s.version                 = "8.2.1"
   s.name                    = "UrbanAirship-iOS-SDK"
   s.summary                 = "Urban Airship iOS SDK"

   s.documentation_url       = "http://docs.urbanairship.com/platform/ios.html"
   s.homepage                = "https://www.urbanairship.com"
   s.author                  = { "Urban Airship" => "support@urbanairship.com" }

   s.license                 = { :type => 'BSD', :file => 'LICENSE' }
   s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }

   s.module_name             = "AirshipKit"
   s.ios.deployment_target   = "8.0"
   s.requires_arc            = true

   s.ios.resource_bundle     = { 'AirshipResources' =>  ['AirshipKit/AirshipResources/*'] }
   s.ios.source_files        = 'AirshipKit/AirshipKit/*.{h,m,mm}'

   s.libraries               = 'z', 'sqlite3'
   s.ios.frameworks          = 'UserNotifications', 'CFNetwork', 'CoreGraphics', 'Foundation', 'MobileCoreServices', 'Security', 'SystemConfiguration', 'UIKit', 'CoreTelephony', 'CoreLocation', 'CoreData'
end
