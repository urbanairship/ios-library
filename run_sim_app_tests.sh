#!/bin/bash

if [ "$RUN_UNIT_TEST_WITH_IOS_SIM" = "YES" ]; then

   echo "Running application tests with ios-sim."

    test_bundle_path="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.$WRAPPER_EXTENSION"
    environment_args="--setenv DYLD_INSERT_LIBRARIES=/../../Library/PrivateFrameworks/IDEBundleInjection.framework/IDEBundleInjection --setenv XCInjectBundle=$test_bundle_path --setenv XCInjectBundleInto=$TEST_HOST"
    test_host_dir=$(dirname $TEST_HOST)

    # record the output in a temp file so that we can parse it later and determine whether or not the tests ran and succeeded
    test_logfile=$(mktemp /tmp/ios_application_tests_log.XXXXXX)

    # launch the simulator using ios-sim
    # ios-sim prefixes every buffered line (i.e., some "lines" can contain linebreaks) with "[DEBUG] ", which breaks the Jenkins Xcode plugin parser (it matches entire lines, so the prefix causes it to lose track of tests)
    # as well, _most_ ios-sim output is sent to stderr, so we redirect stderr to stdout and strip the prefix with sed
    # There's more! ios-sim will ALWAYS exit 1 (error) when running tests, because the app closes itself when the test suite is complete
    # to work around this, we tee output to the temp file created above and parse it below so that we can return the proper exit code for Jenkins
    # The ios-sim process will exit 1, but since it's piped to sed and tee, the line below will exit 0 and we can proceed to the parsing step.
    /usr/local/bin/ios-sim launch $test_host_dir $environment_args --args -SenTest All -ApplePersistenceIgnoreState YES -NSTreatUnknownArgumentsAsOpen NO $test_bundle_path 2>&1 | sed -E 's/^\[DEBUG\][ \t]*//g' | tee ${test_logfile}

    # Test the log output for test case failure. If this line is present, exit 1
    if egrep "Test Case '-\[[[:alnum:]]+[[:space:]][[:alnum:]]+\]' failed" ${test_logfile}
    then
        echo "A test failed."
        exit 1
    fi

    # Test the log output for a success message. If this line is not present, it means that something failed
    # before the test suite could finish (e.g., the sim could not start), so we will exit 1
    if egrep --quiet "Test Suite 'All tests' finished" ${test_logfile}
    then
        echo "The test suite finished successfully."
    else
        echo "The test suite did not finish."
        exit 1
    fi

else
    echo "ios-sim test runner is disabled."
    
    # The standard toolchain test runner could be invoked with the following:
    # "${SYSTEM_DEVELOPER_DIR}/Tools/RunUnitTests"
fi
