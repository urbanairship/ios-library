workspace 'Airship'
platform :ios, '10.0'
use_frameworks!

target 'AirshipKitTests' do
   project 'AirshipKit/AirshipKit.xcodeproj'
   pod 'OCMock', '~> 3.4'
   pod 'XcodeEdit', '~> 1.1'
end

# remove this when OCMock fixes documentation warning
post_install do |installer|
    installer.pods_project.targets.each do |target|
        if target.name == 'OCMock'
            target.build_configurations.each do |config|
                config.build_settings['CLANG_WARN_DOCUMENTATION_COMMENTS'] = 'NO'
            end
        end
    end
end
