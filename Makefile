
XCODE ?= 26.0

export XCBEAUTIY_RENDERER ?= github-actions
export TEST_DESTINATION ?= platform=iOS Simulator,OS=26.0,name=iPhone 16 Pro Max
export TEST_DESTINATION_TVOS ?= platform=tvOS Simulator,OS=26.0,name=Apple TV
export TEST_DESTINATION_VISIONOS ?= platform=visionOS Simulator,OS=2.0,name=Apple Vision Pro

export DEVELOPER_DIR = $(shell bash ./scripts/get_xcode_path.sh ${XCODE} $(XCODE_PATH))
export AIRSHIP_VERSION = $(shell bash "./scripts/airship_version.sh")


build_path = build
derived_data_path = ${build_path}/derived_data
archive_path = ${build_path}/archive

xcframeworks_path = ${build_path}/xcframeworks
docs_path = ${build_path}/Documentation
package_zip_path = ${build_path}/Airship.zip
package_carthage_zip_path = ${build_path}/Airship.xcframeworks.zip
file_size=${build_path}/size.txt
previous_file_size=${build_path}/previous-size.txt

.PHONY: setup
setup:
	test ${DEVELOPER_DIR}
	bundle install --quiet
	bash ./scripts/check_xcbeautify.sh

.PHONY: all
all: setup build test pod-lint

.PHONY: build
build: build-package build-samples

.PHONY: build-package
build-package: clean-package build-docs build-xcframeworks
	bash ./scripts/package.sh \
	 "${package_zip_path}" \
	 "${xcframeworks_path}/*.xcframework" \
	 "${docs_path}" \
	 CHANGELOG.md \
	 README.md \
	 LICENSE
	bash ./scripts/package_carthage.sh "${package_carthage_zip_path}" "${xcframeworks_path}/" 

.PHONY: build-docC
build-docC:
	bash ./scripts/build_docCs.sh $(version)
	
.PHONY: build-docs
build-docs: setup clean-docs
	bash ./scripts/build_docs.sh "${docs_path}"

.PHONY: build-xcframeworks
build-xcframeworks: setup clean-xcframeworks
	bash ./scripts/build_xcframeworks.sh "${xcframeworks_path}" "${derived_data_path}" "${archive_path}"

.PHONY: build-samples
build-samples: build-sample-ios

.PHONY: build-sample-ios
build-sample-ios: setup
	bash ./scripts/build_sample.sh "DevApp" "${derived_data_path}"
	
.PHONY: build-sample-watchos
build-sample-watchos: setup
	bash ./scripts/build_sample_watchos.sh "watchOSSample_WatchKit_Extension" "${derived_data_path}"
	

.PHONY: test
test: setup test-core test-preference-center test-message-center test-automation test-feature-flags test-service-extension

.PHONY: test-core
test-core: setup
	bash ./scripts/run_tests.sh AirshipCore "${derived_data_path}"

.PHONY: test-message-center
test-message-center: setup
	bash ./scripts/run_tests.sh AirshipMessageCenter "${derived_data_path}"

.PHONY: test-preference-center
test-preference-center: setup
	bash ./scripts/run_tests.sh AirshipPreferenceCenter "${derived_data_path}"

.PHONY: test-automation
test-automation: setup
	bash ./scripts/run_tests.sh AirshipAutomation "${derived_data_path}"

.PHONY: test-feature-flags
test-feature-flags: setup
	bash ./scripts/run_tests.sh AirshipFeatureFlags "${derived_data_path}"

.PHONY: test-service-extension
test-service-extension: setup
	bash ./scripts/run_tests.sh AirshipNotificationServiceExtension "${derived_data_path}"

.PHONY: test-packages
test-packages: setup
	bash ./scripts/test_package.sh spm

.PHONY: pod-publish
pod-publish: setup
	bundle exec pod trunk push Airship.podspec --allow-warnings
	bundle exec pod trunk push AirshipServiceExtension.podspec --allow-warnings

.PHONY: pod-lint
pod-lint: pod-lint-tvos pod-lint-ios pod-lint-extensions

.PHONY: pod-lint-tvos
pod-lint-tvos: setup
	bundle exec pod lib lint Airship.podspec --verbose --platforms=tvos --fail-fast --skip-tests --no-subspecs --allow-warnings

.PHONY: pod-lint-watchos
pod-lint-watchos: setup
	bundle exec pod lib lint Airship.podspec --verbose --platforms=watchos --subspec=Core --fail-fast --skip-tests --no-clean --allow-warnings

.PHONY: pod-lint-ios
pod-lint-ios: setup
	bundle exec pod lib lint Airship.podspec --verbose --platforms=ios  --fail-fast --skip-tests --no-subspecs --allow-warnings

.PHONY: pod-lint-visionos
pod-lint-visionos: setup
	bundle exec pod lib lint Airship.podspec --verbose --platforms=visionOS  --fail-fast --skip-tests --no-subspecs --allow-warnings

.PHONY: pod-lint-extensions
pod-lint-extensions: setup
	bundle exec pod lib lint AirshipServiceExtension.podspec --verbose --platforms=ios  --fail-fast --skip-tests --allow-warnings

.PHONY: clean
clean:
	rm -rf "${build_path}"

.PHONY: clean-docs
clean-docs:
	rm -rf "${docs_path}"

.PHONY: clean-package
clean-package:
	rm -rf "${package_zip_path}"
	rm -rf "${package_carthage_zip_path}"

.PHONY: clean-xcframeworks
clean-xcframeworks:
	# rm -rf "${xcframeworks_path}"
	
.PHONY: compare-framework-size
compare-framework-size: build-xcframeworks check-size

.PHONY: check-size
check-size:
	bash ./scripts/check_size.sh "${xcframeworks_path}" "${file_size}" "${previous_file_size}"
	
