AIRSHIP_VERSION="17.7.1"

Pod::Spec.new do |s|
   s.version                    = AIRSHIP_VERSION
   s.name                       = "Airship"
   s.summary                    = "Airship iOS SDK"
   s.documentation_url          = "https://docs.airship.com/platform/ios"
   s.homepage                   = "https://www.airship.com"
   s.author                     = { "Airship" => "support@airship.com" }
   s.license                    = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
   s.source                     = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }
   s.module_name                = "AirshipKit"
   s.header_dir                 = "AirshipKit"
   s.ios.deployment_target      = "14.0"
   s.tvos.deployment_target     = "14.0"
   s.watchos.deployment_target  = "7.0"
   s.swift_versions             = "5.0"
   s.requires_arc               = true
   s.default_subspecs           = ["Basement", "Core", "Automation", "MessageCenter", "PreferenceCenter", "FeatureFlags"]

   s.subspec "Basement" do |basement|
      basement.public_header_files        = "Airship/AirshipBasement/Source/Public/*.h", "Cocoapods/AirshipKit.h"
      basement.source_files               = "Airship/AirshipBasement/Source/Public/*.h", "Airship/AirshipBasement/Source/Internal/*.{h,m}", "Cocoapods/AirshipKit.h"
      basement.private_header_files       = "Airship/AirshipBasement/Source/Internal/*.h"
      basement.exclude_files              = "Airship/AirshipBasement/Source/Public/AirshipBasement.h"
      basement.libraries                  = "z", "sqlite3"
      basement.frameworks                 = "UserNotifications", "CFNetwork", "CoreGraphics", "Foundation", "Security", "UIKit", "CoreData"
      basement.ios.frameworks             = "WebKit", "CoreTelephony","SystemConfiguration"
      basement.tvos.frameworks            = "SystemConfiguration"
      basement.watchos.frameworks         = "WatchKit"
   end

   s.subspec "Core" do |core|
      core.source_files               = "Airship/AirshipCore/Source/*.{swift}"
      core.resource_bundle            = { 'AirshipCoreResources' => "Airship/AirshipCore/Resources/*" }
      core.exclude_files              = "Airship/AirshipCore/Resources/Info.plist", "Airship/AirshipCore/Source/AirshipCore.h"
      core.libraries                  = "z", "sqlite3"
      core.frameworks                 = "UserNotifications", "CFNetwork", "CoreGraphics", "Foundation", "Security", "UIKit", "CoreData"
      core.ios.frameworks             = "WebKit", "CoreTelephony", "SystemConfiguration", "StoreKit"
      core.tvos.frameworks            = "SystemConfiguration"
      core.watchos.frameworks         = "WatchKit"
      core.dependency                 "Airship/Basement"
   end

   s.subspec "Automation" do |automation|
      automation.ios.source_files          = "Airship/AirshipAutomation/Source/**/*.{h,m,swift}"
      automation.ios.exclude_files         = "Airship/AirshipAutomation/Source/AirshipAutomation.h"
      automation.ios.resource_bundle       = { 'AirshipAutomationResources' => "Airship/AirshipAutomation/Resources/**/*" }
      automation.dependency                "Airship/Core"
   end

   s.subspec "MessageCenter" do |messageCenter|
      messageCenter.ios.source_files          = "Airship/AirshipMessageCenter/Source/**/*.{h,m,swift}"
      messageCenter.ios.exclude_files         = "Airship/AirshipMessageCenter/Source/AirshipMessageCenter.h"
      messageCenter.ios.resource_bundle       = { 'AirshipMessageCenterResources' => "Airship/AirshipMessageCenter/Resources/**/*" }
      messageCenter.dependency                "Airship/Core"
   end

   s.subspec "PreferenceCenter" do |preferenceCenter|
      preferenceCenter.ios.source_files              = "Airship/AirshipPreferenceCenter/Source/**/*.{h,m,swift}"
      preferenceCenter.ios.exclude_files             = "Airship/AirshipPreferenceCenter/Source/AirshipPreferenceCenter.h"
      preferenceCenter.dependency                      "Airship/Core"
   end

   s.subspec "FeatureFlags" do |airshipFeatureFlags|
      airshipFeatureFlags.ios.source_files              = "Airship/AirshipFeatureFlags/Source/**/*.{h,m,swift}"
      airshipFeatureFlags.ios.exclude_files             = "Airship/AirshipFeatureFlags/Source/AirshipFeatureFlags.h"
      airshipFeatureFlags.dependency                      "Airship/Core"
   end
end
