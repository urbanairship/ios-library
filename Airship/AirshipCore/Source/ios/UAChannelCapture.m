/* Copyright Airship and Contributors */

#import "UAChannelCapture+Internal.h"
#import "NSString+UALocalizationAdditions.h"
#import "UAirship.h"
#import "UAChannel.h"
#import "UAPushProviderDelegate.h"
#import "UAPush+Internal.h"
#import "UARuntimeConfig.h"
#import "UA_Base64.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UAUtils+Internal.h"
#import "UADispatcher.h"
#import "UAAppStateTracker.h"

NSString *const UAChannelCaptureEnabledKey = @"UAChannelCaptureEnabled";

@interface UAChannelCapture()
@property (nonatomic, strong) UAChannel *channel;
@property (nonatomic, strong) id<UAPushProviderDelegate> pushProviderDelegate;
@property (nonatomic, strong) UARuntimeConfig *config;
@property (nonatomic, strong) UAPreferenceDataStore *dataStore;
@property (nonatomic, strong) UADispatcher *backgroundDispatcher;
@property (nonatomic, strong) UADispatcher *mainDispatcher;
@property bool enableChannelCapture;
@end

@implementation UAChannelCapture

NSString *const UAChannelBaseURL = @"https://go.urbanairship.com/";
NSString *const UAChannelPlaceHolder = @"CHANNEL";

- (instancetype)initWithConfig:(UARuntimeConfig *)config
                       channel:(UAChannel *)channel
          pushProviderDelegate:(id<UAPushProviderDelegate>)pushProviderDelegate
                     dataStore:(UAPreferenceDataStore *)dataStore
            notificationCenter:(NSNotificationCenter *)notificationCenter
                mainDispatcher:(UADispatcher *)mainDispatcher
          backgroundDispatcher:(UADispatcher *)backgroundDispatcher {
    self = [super init];
    if (self) {
        self.config = config;
        self.channel = channel;
        self.pushProviderDelegate = pushProviderDelegate;
        self.dataStore = dataStore;

        if (config.channelCaptureEnabled) {
            self.mainDispatcher = mainDispatcher;
            self.backgroundDispatcher = backgroundDispatcher;
            self.enableChannelCapture = true;

            [notificationCenter addObserver:self selector:@selector(applicationDidBecomeActive)
                                       name:UAApplicationDidBecomeActiveNotification
                                     object:nil];
        }
    }

    return self;
}

+ (instancetype)channelCaptureWithConfig:(UARuntimeConfig *)config
                                 channel:(UAChannel *)channel
                    pushProviderDelegate:(id<UAPushProviderDelegate>)pushProviderDelegate
                               dataStore:(UAPreferenceDataStore *)dataStore {
    return [[UAChannelCapture alloc] initWithConfig:config
                                            channel:channel
                               pushProviderDelegate:pushProviderDelegate
                                          dataStore:dataStore
                                 notificationCenter:[NSNotificationCenter defaultCenter]
                                     mainDispatcher:[UADispatcher mainDispatcher]
                               backgroundDispatcher:[UADispatcher backgroundDispatcher]];
}

+ (instancetype)channelCaptureWithConfig:(UARuntimeConfig *)config
                                 channel:(UAChannel *)channel
                    pushProviderDelegate:(id<UAPushProviderDelegate>)pushProviderDelegate
                               dataStore:(UAPreferenceDataStore *)dataStore
                      notificationCenter:(NSNotificationCenter *)notificationCenter
                          mainDispatcher:(UADispatcher *)mainDispatcher
                    backgroundDispatcher:(UADispatcher *)backgroundDispatcher {
    return [[UAChannelCapture alloc] initWithConfig:config
                                            channel:channel
                               pushProviderDelegate:pushProviderDelegate
                                          dataStore:dataStore
                                    notificationCenter:notificationCenter
                                     mainDispatcher:mainDispatcher
                               backgroundDispatcher:backgroundDispatcher];
}

- (void)enable:(NSTimeInterval)duration {
    NSDate *date = [NSDate dateWithTimeIntervalSinceNow:duration];
    [self.dataStore setObject:date forKey:UAChannelCaptureEnabledKey];
    self.enableChannelCapture = true;
}

- (void)disable {
    [self.dataStore removeObjectForKey:UAChannelCaptureEnabledKey];
    self.enableChannelCapture = false;
}

- (void)applicationDidBecomeActive {
    [self checkClipboard];
}

/**
 * Checks the clipboard for the token and displays an alert if the token is available.
 */
- (void)checkClipboard {
    if (!self.channel.identifier || !self.enableChannelCapture) {
        return;
    }

    if (self.pushProviderDelegate.backgroundPushNotificationsAllowed) {
        NSDate *enabledUntilDate = [self.dataStore objectForKey:UAChannelCaptureEnabledKey];
        if (!enabledUntilDate || [enabledUntilDate compare:[NSDate date]] == NSOrderedAscending) {
            return;
        }
    }

    if (![UIPasteboard generalPasteboard].hasStrings) {
        return;
    }

    NSString *pasteBoardString = [UIPasteboard generalPasteboard].string;
    if (!pasteBoardString.length) {
        return;
    }

    // Do the heavy lifting off the main queue
    [self.backgroundDispatcher dispatchAsync:^{
        NSData *base64Data = UA_dataFromBase64String(pasteBoardString);
        if (!base64Data) {
            return;
        }

        NSString *decodedPasteBoardString = [[NSString alloc] initWithData:base64Data encoding:NSUTF8StringEncoding];
        if (!decodedPasteBoardString.length) {
            return;
        }

        NSString *token = [self generateToken];
        if (![decodedPasteBoardString hasPrefix:token]) {
            return;
        }

        // Generate the URL
        NSURL *url;
        if (decodedPasteBoardString.length > token.length) {
            // Generate the URL
            NSString *urlString = [decodedPasteBoardString stringByReplacingOccurrencesOfString:token
                                                                                     withString:UAChannelBaseURL];

            urlString = [urlString stringByReplacingOccurrencesOfString:UAChannelPlaceHolder
                                                             withString:self.channel.identifier];

            urlString = [urlString stringByTrimmingCharactersInSet:
                         [NSCharacterSet whitespaceAndNewlineCharacterSet]];

            url = [NSURL URLWithString:urlString];
        }

        // Move back to the main queue to clear the clipboard and display the alert
        [self.mainDispatcher dispatchAsync:^{
            [UIPasteboard generalPasteboard].string = @"";
            [self showAlertWithUrl:url];
        }];
    }];
}

- (void)showAlertWithUrl:(NSURL *)url {


    UIAlertController *controller = [UIAlertController alertControllerWithTitle:[@"ua_channel_id" localizedStringWithTable:@"UrbanAirship" defaultValue:@"Channel ID"]
                                                                        message:self.channel.identifier
                                                                 preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:[@"ua_cancel" localizedStringWithTable:@"UrbanAirship" defaultValue:@"Cancel"]
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];

    [controller addAction:cancelAction];

    NSString *channelID = self.channel.identifier;
    UIAlertAction *copyAction  = [UIAlertAction actionWithTitle:[@"ua_notification_button_copy" localizedStringWithTable:@"UrbanAirship" defaultValue:@"Copy"]
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction *action) {
                                                            [UIPasteboard generalPasteboard].string = channelID ?: @"";
                                                            UA_LINFO(@"Copied channel %@ to the pasteboard", channelID);
                                                        }];
    [controller addAction:copyAction];


    if (url) {
        UIAlertAction *urlAction  = [UIAlertAction actionWithTitle:[@"ua_notification_button_save" localizedStringWithTable:@"UrbanAirship" defaultValue:@"Save"]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction *action) {
                                                               [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:^(BOOL success) {
                                                                   if (success) {
                                                                       UA_LINFO(@"Opened url: %@", url.absoluteString);
                                                                   } else {
                                                                       UA_LDEBUG(@"Failed to open url: %@", url.absoluteString);
                                                                   }
                                                               }];
                                                           }];
        [controller addAction:urlAction];
    }

    controller.popoverPresentationController.sourceView = [UAUtils mainWindow].rootViewController.view;
    [[UAUtils mainWindow].rootViewController presentViewController:controller animated:YES completion:nil];
}

/**
 * Generates the expected clipboard token.
 *
 * @return The generated clipboard token.
 */
- (NSString *)generateToken {
    const char *keyCStr = [self.config.appKey cStringUsingEncoding:NSASCIIStringEncoding];
    size_t keyCstrLen = strlen(keyCStr);

    const char *secretCStr = [self.config.appSecret cStringUsingEncoding:NSASCIIStringEncoding];
    size_t secretCstrLen = strlen(secretCStr);

    NSMutableString *combined = [NSMutableString string];
    for (size_t i = 0; i < keyCstrLen; i++) {
        [combined appendFormat:@"%02x", (int)(keyCStr[i] ^ secretCStr[i % secretCstrLen])];
    }

    return combined;
}

@end


