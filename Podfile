workspace 'Airship'
use_frameworks!

target 'AirshipCoreTests' do
  platform :ios, '11.0'
  project 'Airship/Airship.xcodeproj'
  pod 'OCMock', '~> 3.4.1'
  pod 'XcodeEdit', '~> 2.7.4'
end

target 'Sample' do
    platform :ios, '11.0'
    project 'Sample/Sample.xcodeproj'
    pod 'Airship', :path => './'
    pod 'Airship/Location', :path => './'
    pod 'Airship/Debug', :path => './'
 end

target 'SampleServiceExtension' do
  platform :ios, '11.0'
  project 'Sample/Sample.xcodeproj'
  pod 'AirshipExtensions', :path => './'
end

target 'SampleContentExtension' do
  platform :ios, '11.0'
  project 'Sample/Sample.xcodeproj'
  pod 'AirshipExtensions', :path => './'
end

target 'SwiftSample' do
  platform :ios, '11.0'
  project 'SwiftSample/SwiftSample.xcodeproj'
  pod 'Airship', :path => './'
  pod 'Airship/Location', :path => './'
  pod 'Airship/Debug', :path => './'
end

target 'SwiftSampleServiceExtension' do
  platform :ios, '11.0'
  project 'SwiftSample/SwiftSample.xcodeproj'
  pod 'AirshipExtensions', :path => './'
end

target 'SwiftSampleContentExtension' do
  platform :ios, '11.0'
  project 'SwiftSample/SwiftSample.xcodeproj'
  pod 'AirshipExtensions', :path => './'
end

