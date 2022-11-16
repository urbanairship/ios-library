AIRSHIP_VERSION="16.10.3"

Pod::Spec.new do |s|
   s.version                 = AIRSHIP_VERSION
   s.name                    = "Airship"
   s.summary                 = "Airship iOS SDK"
   s.documentation_url       = "https://docs.airship.com/platform/ios"
   s.homepage                = "https://www.airship.com"
   s.author                  = { "Airship" => "support@airship.com" }
   s.license                 = { :type => "Apache License, Version 2.0", :file => "LICENSE" }
   s.source                  = { :git => "https://github.com/urbanairship/ios-library.git", :tag => s.version.to_s }
   s.module_name             = "AirshipKit"
   s.header_dir              = "AirshipKit"
   s.ios.deployment_target   = "11.0"
   s.tvos.deployment_target  = "11.0"
   s.swift_versions          = "5.0"
   s.requires_arc            = true
   s.default_subspecs        = ["Basement", "Core", "Automation", "MessageCenter", "ExtendedActions"]

   s.subspec "Basement" do |basement|
      basement.public_header_files        = "Airship/AirshipBasement/Source/Public/*.h", "Cocoapods/AirshipKit.h"
      basement.source_files               = "Airship/AirshipBasement/Source/Public/*.h", "Airship/AirshipBasement/Source/Internal/*.{h,m}", "Cocoapods/AirshipKit.h"
      basement.private_header_files       = "Airship/AirshipBasement/Source/Internal/*.h"
      basement.exclude_files              = "Airship/AirshipBasement/Source/Public/AirshipBasement.h"
      basement.libraries                  = "z", "sqlite3"
      basement.frameworks                 = "UserNotifications", "CFNetwork", "CoreGraphics", "Foundation", "Security", "SystemConfiguration", "UIKit", "CoreData"
      basement.ios.frameworks             = "WebKit", "CoreTelephony"
   end

   s.subspec "Core" do |core|
      core.source_files               = "Airship/AirshipCore/Source/*.{swift}"
      core.resource_bundle            = { 'AirshipCoreResources' => "Airship/AirshipCore/Resources/*" }
      core.exclude_files              = "Airship/AirshipCore/Resources/Info.plist", "Airship/AirshipCore/Source/AirshipCore.h"
      core.libraries                  = "z", "sqlite3"
      core.frameworks                 = "UserNotifications", "CFNetwork", "CoreGraphics", "Foundation", "Security", "SystemConfiguration", "UIKit", "CoreData"
      core.ios.frameworks             = "WebKit", "CoreTelephony"
      core.dependency                 "Airship/Basement"
   end
   s.subspec "ExtendedActions" do |actions|
      actions.ios.public_header_files    = "Airship/AirshipExtendedActions/Source/Public/*.h"
      actions.ios.source_files           = "Airship/AirshipExtendedActions/Source/**/*.{h,m}", "Airship/AirshipExtendedActions/Source/Public/**/*.{h,m}"
      actions.ios.private_header_files   = "Airship/AirshipExtendedActions/Source/**/*+Internal*.h"
      actions.ios.resource_bundle        = { 'AirshipExtendedActionsResources' => "Airship/AirshipExtendedActions/Resources/*" }
      actions.ios.exclude_files          = "Airship/AirshipExtendedActions/Resources/Info.plist", "Airship/AirshipExtendedActions/Source/AirshipExtendedActions.h"
      actions.ios.frameworks             = "StoreKit"
      actions.dependency                 "Airship/Core"
   end

   s.subspec "Location" do |location|
      location.ios.public_header_files    = "Airship/AirshipLocation/Source/Public/*.h"
      location.ios.source_files           = "Airship/AirshipLocation/Source/*.{h,m}", "Airship/AirshipLocation/Source/Public/**/*.{h,m}"
      location.ios.private_header_files   = "Airship/AirshipLocation/Source/*+Internal*.h"
      location.ios.exclude_files          = "Airship/AirshipLocation/Source/AirshipLocation.h"
      location.ios.frameworks             = "CoreLocation"
      location.dependency                  "Airship/Core"
   end

   s.subspec "Automation" do |automation|
      automation.ios.public_header_files       = "Airship/AirshipAutomation/Source/Public/*.h"
      automation.ios.source_files              = "Airship/AirshipAutomation/Source/**/*.{h,m}", "Airship/AirshipAutomation/Source/Public/**/*.{h,m}"
      automation.ios.resource_bundle           = { 'AirshipAutomationResources' => "Airship/AirshipAutomation/Resources/*" }
      automation.ios.exclude_files             = "Airship/AirshipAutomation/Resources/Info.plist", "Airship/AirshipAutomation/Source/AirshipAutomation.h"
      automation.ios.frameworks                = "UIKit"
      automation.dependency                    "Airship/Core"
   end

   s.subspec "MessageCenter" do |messageCenter|
      messageCenter.ios.public_header_files   = "Airship/AirshipMessageCenter/Source/Public/*.h"
      messageCenter.ios.source_files          = "Airship/AirshipMessageCenter/Source/**/*.{h,m}", "Airship/AirshipMessageCenter/Source/Public/**/*.{h,m}"
      messageCenter.ios.private_header_files  = "Airship/AirshipMessageCenter/Source/**/*+Internal*.h"
      messageCenter.ios.resource_bundle       = { 'AirshipMessageCenterResources' => "Airship/AirshipMessageCenter/Resources/*" }
      messageCenter.ios.exclude_files         = "Airship/AirshipMessageCenter/Resources/Info.plist", "Airship/AirshipMessageCenter/Source/AirshipMessageCenter.h"
      messageCenter.dependency                  "Airship/Core"
   end

   s.subspec "Accengage" do |accengage|
      accengage.ios.public_header_files   = "Airship/AirshipAccengage/Source/Public/*.h"
      accengage.ios.source_files          = "Airship/AirshipAccengage/Source/**/*.{h,m}", "Airship/AirshipAccengage/Source/Public/**/*.{h,m}"
      accengage.ios.private_header_files  = "Airship/AirshipAccengage/Source/**/*+Internal*.h"
      accengage.ios.exclude_files         = "Airship/AirshipAccengage/Source/AirshipAccengage.h"
      accengage.ios.resource_bundle       = { 'AirshipAccengageResources' => "Airship/AirshipAccengage/Resources/**/*" }
      accengage.dependency                  "Airship/Core"
   end

   s.subspec "Chat" do |chat|
      chat.ios.source_files              = "Airship/AirshipChat/Source/**/*.{h,m,swift}"
      chat.ios.exclude_files             = "Airship/AirshipChat/Source/AirshipChat.h"
      chat.ios.resource_bundle           = { 'AirshipChatResources' => "Airship/AirshipChat/Resources/**/*" }
      chat.dependency                      "Airship/Core"
   end
 
   s.subspec "PreferenceCenter" do |preferenceCenter|
      preferenceCenter.ios.source_files              = "Airship/AirshipPreferenceCenter/Source/**/*.{h,m,swift}"
      preferenceCenter.ios.exclude_files             = "Airship/AirshipPreferenceCenter/Source/AirshipPreferenceCenter.h"
      preferenceCenter.ios.resource_bundle           = { 'AirshipPreferenceCenterResources' => "Airship/AirshipPreferenceCenter/Resources/**/*" }
      preferenceCenter.dependency                      "Airship/Core"
   end
end
