AIRSHIP_VERSION="20.6.1"

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
   s.ios.deployment_target      = "16.0"
   s.tvos.deployment_target     = "18.0"
   s.watchos.deployment_target  = "11.0"
   s.swift_versions             = "6.0"
   s.requires_arc               = true
   s.default_subspecs           = ["Basement", "Core", "Automation", "MessageCenter", "PreferenceCenter", "FeatureFlags"]

   s.subspec "Basement" do |basement|
      basement.source_files               = "Airship/AirshipBasement/Source/**/*.{swift}"
   end

   s.subspec "Core" do |core|
      core.source_files               = "Airship/AirshipCore/Source/**/*.{swift}"
      core.resource_bundle            = { 'AirshipCoreResources' => "Airship/AirshipCore/Resources/**/*" }
      core.exclude_files              = "Airship/AirshipCore/Resources/Info.plist"
      core.dependency                 "Airship/Basement"
   end

   s.subspec "Automation" do |automation|
      automation.ios.source_files          = "Airship/AirshipAutomation/Source/**/*.{swift}"
      automation.ios.resource_bundle       = { 'AirshipAutomationResources' => "Airship/AirshipAutomation/Resources/**/*" }
      automation.dependency                "Airship/Core"
   end

   s.subspec "MessageCenter" do |messageCenter|
      messageCenter.ios.source_files          = "Airship/AirshipMessageCenter/Source/**/*.{swift}"
      messageCenter.ios.resource_bundle       = { 'AirshipMessageCenterResources' => "Airship/AirshipMessageCenter/Resources/**/*" }
      messageCenter.dependency                "Airship/Core"
   end

   s.subspec "PreferenceCenter" do |preferenceCenter|
      preferenceCenter.ios.source_files              = "Airship/AirshipPreferenceCenter/Source/**/*.{swift}"
      preferenceCenter.dependency                      "Airship/Core"
   end

   s.subspec "FeatureFlags" do |airshipFeatureFlags|
      airshipFeatureFlags.ios.source_files              = "Airship/AirshipFeatureFlags/Source/**/*.{swift}"
      airshipFeatureFlags.dependency                      "Airship/Core"
   end

   s.subspec "ObjectiveC" do |objectiveC|
      objectiveC.ios.source_files              = "Airship/AirshipObjectiveC/Source/**/*.{swift}"
      objectiveC.dependency                      "Airship/Core"
      objectiveC.dependency                      "Airship/Automation"
      objectiveC.dependency                      "Airship/MessageCenter"
      objectiveC.dependency                      "Airship/PreferenceCenter"
      objectiveC.dependency                      "Airship/FeatureFlags"
   end
end
