Pod::Spec.new do |s|
  s.name         = 'UrbanAirship-iOS-SDK'
  s.version      = '3.0.4'
  s.license      = 'BSD'
  s.platform     = :ios

  s.summary      = 'A simple way to integrate Urban Airship services into your iOS applications.'
  s.homepage     = 'https://github.com/urbanairship/ios-library'
  s.author       = { 'Urban Airship' => 'support@urbanairship.com' }
  s.source       = { :git => 'https://github.com/urbanairship/ios-library.git', :tag => s.version.to_s }
  
  # Airship ships both UA-prefixed ASI and SBJson, as well as un-prefixed
  # versions that are no longer used in the .xcodeproj.
  s.requires_arc = true
  s.libraries    = 'z', 'sqlite3.0'
  s.frameworks   = 'CFNetwork', 'CoreGraphics', 'Foundation', 'MobileCoreServices',
                   'Security', 'SystemConfiguration', 'UIKit', 'CoreTelephony', 'CoreLocation'
  
  s.platform = :ios, '5.1'

  s.default_subspec = 'Core'

  s.subspec 'Core' do |ss|
    ss.source_files = 'Airship/{Common,Inbox,Push,External}/**.{h,m,c}', 'Airship/UI/Default/Push/Classes/Shared/UAPushNotificationHandler.h'
    ss.ios.frameworks = 'CFNetwork', 'Foundation', 'MobileCoreServices',
                   'Security', 'SystemConfiguration', 'CoreTelephony', 'CoreLocation'
  end

  s.subspec 'UI' do |ss|
    ss.dependency 'UrbanAirship-iOS-SDK/Core'
    ss.source_files = 'Airship/UI/**/*.{h,m,c}'
    ss.resources = 'Airship/UI/**/*.{xib,jpg,png,bundle}'    
    ss.ios.frameworks = 'CFNetwork', 'CoreGraphics', 'Foundation', 'MobileCoreServices',
                   'Security', 'SystemConfiguration', 'UIKit', 'CoreTelephony', 'CoreLocation'
  end

end

