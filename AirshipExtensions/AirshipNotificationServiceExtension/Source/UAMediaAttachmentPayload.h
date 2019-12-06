/* Copyright Airship and Contributors */

#import <Foundation/Foundation.h>

/**
 * Model object for notification content override.
 */
__TVOS_PROHIBITED __WATCHOS_PROHIBITED
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
 * Model object for the notification attachment url.
 */
__TVOS_PROHIBITED __WATCHOS_PROHIBITED
@interface UAMediaAttachmentURL : NSObject

/**
 * The url id
 */
@property(nonatomic, readonly) NSString *urlID;

/**
 * The attachment URL
 */
@property(nonatomic, readonly) NSURL *url;

@end


/**
 * Model object for the media attachment device payload
 */
__TVOS_PROHIBITED __WATCHOS_PROHIBITED
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

/**
 * The identifier of the attachement that should be used as a thumbnail.
 */
@property(nonatomic, readonly) NSString *thumbnailID;

@end


