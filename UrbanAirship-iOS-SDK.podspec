Pod::Spec.new do |s|
   s.version                 = "10.2.2"
   s.name                    = "UrbanAirship-iOS-SDK"
   s.summary                 = "Airship iOS SDK"

   s.documentation_url       = "https://docs.airship.com/platform/ios"
   s.homepage                = "https://www.airship.com"
   s.author                  = { "Airship" => "support@airship.com" }

   s.license                 = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
   s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }

   s.module_name             = "AirshipKit"
   s.ios.deployment_target   = "10.0"
   s.tvos.deployment_target  = "10.0"
   s.requires_arc            = true

   s.ios.resource_bundle     = { 'AirshipResources' =>  ['AirshipKit/AirshipResources/common/*', 'AirshipKit/AirshipResources/ios/*'] }
   s.tvos.resource_bundle    = { 'AirshipResources tvOS' =>  ['AirshipKit/AirshipResources/common/*', 'AirshipKit/AirshipResources/tvos/*'] }
   s.ios.exclude_files       = 'AirshipKit/AirshipResources/ios/Info.plist'
   s.tvos.exclude_files      = 'AirshipKit/AirshipResources/tvos/Info.plist'
   s.source_files            = 'AirshipKit/AirshipKit/common/*.{h,m,mm}'
   s.ios.source_files        = 'AirshipKit/AirshipKit/ios/*.{h,m,mm}'
   s.tvos.source_files       = 'AirshipKit/AirshipKit/tvos/*.{h,m,mm}'
   s.ios.private_header_files    = 'AirshipKit/AirshipKit/common/*+Internal*.h','AirshipKit/AirshipKit/ios/*+Internal*.h'
   s.tvos.private_header_files   = 'AirshipKit/AirshipKit/common/*+Internal*.h','AirshipKit/AirshipKit/tvos/*+Internal*.h'

   s.libraries               = 'z', 'sqlite3'
   s.frameworks              = 'UserNotifications', 'CFNetwork', 'CoreGraphics', 'Foundation', 'MobileCoreServices', 'Security', 'SystemConfiguration', 'UIKit', 'CoreData', 'StoreKit'
   s.ios.frameworks          = 'WebKit', 'CoreTelephony'
end
