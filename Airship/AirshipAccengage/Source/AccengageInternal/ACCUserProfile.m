/* Copyright Airship and Contributors */

#import "ACCUserProfile.h"
#import "ACCDeviceInformationSet+Internal.h"

@implementation ACCUserProfile

#pragma mark - Update device information
///--------------------------------------

- (void)updateDeviceInformation:(ACCDeviceInformationSet *)deviceInformation withCompletionHandler:(nullable void(^)(NSError *__nullable error))completionHandler {
    
    // Apply the attribute changes to the channel
    [deviceInformation applyEdits];
    
    if (completionHandler) {
        completionHandler(nil);
    }
}

@end
