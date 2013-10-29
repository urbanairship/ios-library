/*
 Copyright 2009-2013 Urban Airship Inc. All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.

 2. Redistributions in binaryform must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided withthe distribution.

 THIS SOFTWARE IS PROVIDED BY THE URBAN AIRSHIP INC``AS IS'' AND ANY EXPRESS OR
 IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO
 EVENT SHALL URBAN AIRSHIP INC OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "UAConfig.h"

/*
 * Testing extensions to UAConfig
 */
@interface UAConfig () {
  @private
    // the following ivars are for instance-scoped dispatch_once control when parsing
    // provisioning xml files
    dispatch_once_t usesProductionPred_;
    BOOL usesProductionPushServer_;
}

/**
 * The provisioning profile path to use for this configuration. It defaults to the `embedded.mobileprovision` file
 * included with app packages, but it may be customized for testing purposes.
 */
@property (nonatomic, copy) NSString *profilePath;

/*
 * The master secret for running functional tests. Not for use in production!
 */
@property (nonatomic, copy) NSString *testingMasterSecret;

/**
 * Defaults to `YES` if the current device is a simulator. Exposed for testing/mocking purposes.
 */
@property (nonatomic, assign) BOOL isSimulator;

/**
 * Determines whether or not the app is currently configured to use the APNS production servers.
 * @return `YES` if using production servers, `NO` if development servers or if the app is not properly
 * configured for push.
 */
- (BOOL)usesProductionPushServer;

/**
 * Tests if the profile at a given path is set up for the production push environment.
 * @param profilePath The specified path of the profile.
 * @return `YES` if using production servers, `NO` if development servers or if the app is not properly
 * configured for push.
 */
+ (BOOL)isProductionProvisioningProfile:(NSString *)profilePath;

/*
 * Converts string keys from the old ALL_CAPS format to the new property name format. Transforms
 * boolean strings (YES/NO) into NSNumber BOOLs if the target property is a primitive char type. Transforms
 * integer strings ("1", "5", etc. for log levels) into NSNumber objects.
 */
+ (NSDictionary *)normalizeDictionary:(NSDictionary *)keyedValues;

@end


