//
//  UATestPushDelegate.m
//  PushSampleLib
//
//  Created by Jeff Towle on 6/3/13.
//
//

#import "UATestPushDelegate.h"


@implementation UATestPushDelegate

- (void)displayNotificationAlert:(NSString *)alertMessage {
    // display the push with the alert (a UUID) in all fields
    UIAlertView *alert = [[[UIAlertView alloc] initWithTitle: @"alertMessage"
                                                     message:alertMessage
                                                    delegate:nil
                                           cancelButtonTitle:alertMessage
                                           otherButtonTitles:nil] autorelease];
    [alert show];
}

@end
