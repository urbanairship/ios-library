
XCODE ?= 26.6

export XCBEAUTIFY_RENDERER ?= github-actions
export TEST_DESTINATION ?= platform=iOS Simulator,OS=latest,name=iPhone 17 Pro Max
export TEST_DESTINATION_TVOS ?= platform=tvOS Simulator,OS=latest,name=Apple TV
export TEST_DESTINATION_VISIONOS ?= platform=visionOS Simulator,OS=latest,name=Apple Vision Pro

export DEVELOPER_DIR = $(shell bash ./scripts/get_xcode_path.sh ${XCODE} $(XCODE_PATH))
export AIRSHIP_VERSION = $(shell bash "./scripts/airship_version.sh")


build_path = build
derived_data_path = ${build_path}/derived_data
derived_data_devapp_store = ${build_path}/derived_data_devapp_store
devapp_store_out = ${build_path}/devapp_store
archive_path = ${build_path}/archive

xcframeworks_path = ${build_path}/xcframeworks
xcframeworks_full_path = ${xcframeworks_path}/full
xcframeworks_dotnet_path = ${xcframeworks_path}/dotnet
package_zip_path = ${build_path}/Airship.zip
package_xcframeworks_zip_path = ${build_path}/Airship.xcframeworks.zip
package_dotnet_xcframeworks_zip_path = ${build_path}/Airship.dotnet.xcframeworks.zip
file_size=${build_path}/size.txt
previous_file_size=${build_path}/previous-size.txt

.PHONY: setup
setup:
	test ${DEVELOPER_DIR}
	bash ./scripts/check_xcbeautify.sh

.PHONY: all
all: setup build test

.PHONY: build
build: build-package build-samples

.PHONY: build-package
build-package: clean-package build-xcframeworks
	bash ./scripts/package.sh \
	 "${package_zip_path}" \
	 "${xcframeworks_full_path}/*.xcframework" \
	 CHANGELOG.md \
	 README.md \
	 LICENSE
	bash ./scripts/package_xcframeworks.sh "${package_xcframeworks_zip_path}" "${xcframeworks_full_path}/" "Carthage/build"
	bash ./scripts/package_xcframeworks.sh "${package_dotnet_xcframeworks_zip_path}" "${xcframeworks_dotnet_path}/" "xcframeworks"

.PHONY: build-docC
build-docC:
	bash ./scripts/build_docCs.sh $(version)
	

.PHONY: build-xcframeworks
build-xcframeworks: setup clean-xcframeworks
	bash ./scripts/build_xcframeworks.sh "${xcframeworks_path}" "${derived_data_path}" "${archive_path}"

.PHONY: build-xcframeworks-no-sign
build-xcframeworks-no-sign: setup clean-xcframeworks
	bash ./scripts/build_xcframeworks.sh "${xcframeworks_path}" "${derived_data_path}" "${archive_path}" "true"

.PHONY: build-samples
build-samples: build-sample-ios build-sample-macos

.PHONY: build-sample-ios
build-sample-ios: setup
	bash ./scripts/build_sample.sh "DevApp" "${derived_data_path}"

# Release archive + App Store IPA export + altool validation (requires ASC API key + distribution cert in CI).
.PHONY: archive-devapp-store
archive-devapp-store: setup
	bash ./scripts/archive_devapp_store.sh "${derived_data_devapp_store}" "${devapp_store_out}"
	
.PHONY: build-sample-macos
build-sample-macos: setup
	bash ./scripts/build_sample.sh "DevApp" "${derived_data_path}" "macOS"
	
.PHONY: build-sample-watchos
build-sample-watchos: setup
	bash ./scripts/build_sample_watchos.sh "watchOSSample_WatchKit_Extension" "${derived_data_path}"
	
.PHONY: build-airship-objectiveC
build-airship-objectiveC: setup
	bash ./scripts/run_xcodebuild.sh "AirshipObjectiveC" "${derived_data_path}" build

.PHONY: test
test: setup test-basement test-core test-preference-center test-message-center test-scene-renderer test-scenes test-automation test-feature-flags test-service-extension

.PHONY: test-basement
test-basement: setup
	bash ./scripts/run_xcodebuild.sh AirshipBasement "${derived_data_path}" test

.PHONY: test-core
test-core: setup
	bash ./scripts/run_xcodebuild.sh AirshipCore "${derived_data_path}" test

.PHONY: test-message-center
test-message-center: setup
	bash ./scripts/run_xcodebuild.sh AirshipMessageCenter "${derived_data_path}" test

.PHONY: test-preference-center
test-preference-center: setup
	bash ./scripts/run_xcodebuild.sh AirshipPreferenceCenter "${derived_data_path}" test

.PHONY: test-scene-renderer
test-scene-renderer: setup
	bash ./scripts/run_xcodebuild.sh AirshipSceneRenderer "${derived_data_path}" test

.PHONY: test-scenes
test-scenes: setup
	bash ./scripts/run_xcodebuild.sh AirshipScenes "${derived_data_path}" test

.PHONY: test-automation
test-automation: setup
	bash ./scripts/run_xcodebuild.sh AirshipAutomation "${derived_data_path}" test

.PHONY: test-feature-flags
test-feature-flags: setup
	bash ./scripts/run_xcodebuild.sh AirshipFeatureFlags "${derived_data_path}" test

.PHONY: test-service-extension
test-service-extension: setup
	bash ./scripts/run_xcodebuild.sh AirshipNotificationServiceExtension "${derived_data_path}" test


.PHONY: clean
clean:
	rm -rf "${build_path}"

.PHONY: clean-package
clean-package:
	rm -rf "${package_zip_path}"
	rm -rf "${package_xcframeworks_zip_path}"
	rm -rf "${package_dotnet_xcframeworks_zip_path}"

.PHONY: clean-xcframeworks
clean-xcframeworks:
	# rm -rf "${xcframeworks_path}"
	
.PHONY: compare-framework-size
compare-framework-size: build-xcframeworks-no-sign check-size

.PHONY: check-size
check-size:
	bash ./scripts/check_size.sh "${xcframeworks_path}" "${file_size}" "${previous_file_size}"
	
