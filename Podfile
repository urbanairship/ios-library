workspace 'Airship'
use_frameworks!

target 'AirshipTests' do
  platform :ios, '14.0'
  project 'Airship/Airship.xcodeproj'
  pod 'XcodeEdit', '~> 2.7'
end

target 'AirshipNotificationServiceExtensionTests' do
  platform :ios, '14.0'
  project 'AirshipExtensions/AirshipExtensions.xcodeproj'
end

target 'AirshipNotificationContentExtensionTests' do
  platform :ios, '14.0'
  project 'AirshipExtensions/AirshipExtensions.xcodeproj'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
    end
  end
end
