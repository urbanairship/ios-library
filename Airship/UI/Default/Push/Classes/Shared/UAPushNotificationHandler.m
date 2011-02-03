//
//  UAPushNotificationHandler.m
//  PushSampleLib
//
//  Created by Jeff Towle on 2/2/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "UAPushNotificationHandler.h"

#import <AudioToolbox/AudioServices.h> 

@implementation UAPushNotificationHandler

- (void)displayNotificationAlertMessage:(NSString *)alertMessage {
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Notification" 
                                                    message: alertMessage
                                                   delegate: nil
                                          cancelButtonTitle: @"OK"
                                          otherButtonTitles: nil];
	[alert show];
	[alert release];
}

- (void)displayNotificationAlert:(NSDictionary *)alertDict {
    UALOG(@"Got an alert with a body.");
    
    NSString *body = [alertDict valueForKey:@"body"];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Notification" 
                                                    message: body
                                                   delegate: nil
                                          cancelButtonTitle: @"OK"
                                          otherButtonTitles: nil];
	[alert show];
	[alert release];
}

- (void)playNotificationSound:(NSString *)sound {
    
    
    
    UALOG(@"Received an alert with a sound: %@", sound);
    
    if (sound) {
        
        SystemSoundID soundID;
        NSString *path = [[NSBundle mainBundle] pathForResource:[sound stringByDeletingPathExtension] 
                                                         ofType:[sound pathExtension]];
        
        AudioServicesCreateSystemSoundID((CFURLRef)[NSURL fileURLWithPath:path], &soundID);
        AudioServicesPlayAlertSound(soundID);
        
    } else {
        
        // Vibrates on supported devices, on others, does nothing
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
    
    }

}

- (void)handleCustomPayload:(NSDictionary *)data {
    
    UALOG(@"Received an alert with a custom payload");
    
}

- (void)handleBackgroundNotification:(NSDictionary *)notification {
    UALOG(@"The application resumed from a notification.");
}

@end
