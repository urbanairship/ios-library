workspace 'Airship'
platform :ios, '10.0'
use_frameworks!

target 'AirshipKitTests' do
   project 'AirshipKit/AirshipKit.xcodeproj'
   pod 'OCMock', '~> 3.4.1'
   pod 'XcodeEdit', '~> 2.7'
end

target 'TestShipTests' do
   project 'TestShip/TestShip.xcodeproj'
   pod 'KIF', :configurations => ['Debug']
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
	# Disable bitcode in KIF by default because of issue below:
	# https://github.com/kif-framework/KIF/issues/796
        if target.name == 'KIF'
            target.build_configurations.each do |config|
      		config.build_settings['ENABLE_BITCODE'] = 'NO'
            end
        end
    end
end
