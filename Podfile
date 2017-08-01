workspace 'Airship'
platform :ios, '10.0'
use_frameworks!

target 'AirshipKitTests' do
   project 'AirshipKit/AirshipKit.xcodeproj'
   pod 'OCMock', '~> 3.4'
   pod 'XcodeEdit', '~> 1.1'
end

target 'TestShipTests' do
   project 'TestShip/TestShip.xcodeproj'
   pod 'KIF', :configurations => ['Debug']
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
	# remove this when OCMock fixes documentation warning
	if target.name == 'OCMock'
            target.build_configurations.each do |config|
                config.build_settings['CLANG_WARN_DOCUMENTATION_COMMENTS'] = 'NO'
            end
        end
	# disable bitcode in KIF by default
        if target.name == 'KIF'
            target.build_configurations.each do |config|
      		config.build_settings['ENABLE_BITCODE'] = 'NO'
            end
        end
    end
end
