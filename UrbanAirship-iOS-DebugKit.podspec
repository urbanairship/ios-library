Pod::Spec.new do |s|
   s.version                 = "0.1.0"
   s.name                    = "UrbanAirship-iOS-DebugKit"
   s.summary                 = "Urban Airship iOS SDK Debug Library"

   s.documentation_url       = "http://docs.urbanairship.com/platform/ios.html"
   s.homepage                = "https://www.urbanairship.com"
   s.author                  = { "Urban Airship" => "support@urbanairship.com" }

   s.license                 = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
   s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }

   s.module_name             = "AirshipDebugKit"
   s.ios.deployment_target   = "10.0"
   s.requires_arc            = true

   s.source_files            = [ 'AirshipDebugKit/AirshipDebugKit/*.{h,m,swift}', 'AirshipDebugKit/AirshipDebugKit/*/*.{h,m,swift}' ]
   s.swift_version           = "4.2"

   s.resource_bundle         = { 'AirshipDebugResources' =>  ['AirshipDebugKit/AirshipDebugResources/*storyboard'] }

   s.frameworks              = 'UIKit'
   s.dependency                'UrbanAirship-iOS-SDK', '~> 10.0'
end
