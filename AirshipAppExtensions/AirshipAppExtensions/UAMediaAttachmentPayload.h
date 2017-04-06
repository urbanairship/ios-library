/* Copyright 2017 Urban Airship and Contributors */

#import <Foundation/Foundation.h>

/**
 * Model object for notification content override.
 */
@interface UAMediaAttachmentContent : NSObject

/**
 * The notification body.
 */
@property(nonatomic, readonly) NSString *body;

/**
 * The notification title.
 */
@property(nonatomic, readonly) NSString *title;

/**
 * The notification subtitle
 */
@property(nonatomic, readonly) NSString *subtitle;

@end

/**
 * Model object for the media attachment device payload
 */
@interface UAMediaAttachmentPayload : NSObject

/**
 * Factory method for creating a payload from a JSON object
 */
+ (instancetype)payloadWithJSONObject:(id)object;

/**
 * An array of media attachment URLs.
 */
@property(nonatomic, readonly) NSMutableArray *urls;

/**
 * Attachment options in the dictionary format expected by UNNotificationAttachment
 */
@property(nonatomic, readonly) NSDictionary *options;

/**
 * Optional content override for the modified notification.
 */
@property(nonatomic, readonly) UAMediaAttachmentContent *content;

@end


