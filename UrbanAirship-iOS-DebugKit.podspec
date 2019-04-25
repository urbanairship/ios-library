Pod::Spec.new do |s|
   s.version                 = "0.1.0"
   s.name                    = "UrbanAirship-iOS-DebugKit"
   s.summary                 = "Airship iOS SDK Debug Library"

   s.documentation_url       = "https://docs.airship.com/platform/ios"
   s.homepage                = "https://www.airship.com"
   s.author                  = { "Airship" => "support@airship.com" }

   s.license                 = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
   s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }

   s.module_name             = "AirshipDebugKit"
   s.ios.deployment_target   = "10.0"
   s.requires_arc            = true

   s.source_files            = [ 'AirshipDebugKit/AirshipDebugKit/*.{h,m,swift}', 'AirshipDebugKit/AirshipDebugKit/*/*.{h,m,swift}' ]
   s.swift_version           = "4.2"

   s.resources               = ['AirshipDebugKit/AirshipDebugKit/*/*storyboard', 'AirshipDebugKit/AirshipDebugKit/Resources/*' ]

   s.frameworks              = 'UIKit'
   s.dependency                'UrbanAirship-iOS-SDK', '~> 10.0'
end
