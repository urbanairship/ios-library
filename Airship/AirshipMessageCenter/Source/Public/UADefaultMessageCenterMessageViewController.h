/* Copyright Airship and Contributors */

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "UAMessageCenterMessageViewDelegate.h"
#import "UAInboxMessage.h"

#import "UAAirshipMessageCenterCoreImport.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Represents possible error conditions when loading messages.
 */
typedef NS_ENUM(NSInteger, UAMessageCenterMessageLoadErrorCode) {
    /**
     * Indicates that the message list was unavailable.
     */
    UAMessageCenterMessageLoadErrorCodeListUnavailable,
    /**
     * Indicates that an HTTP failure status was encountered.
     */
    UAMessageCenterMessageLoadErrorCodeFailureStatus,
    /**
     * Indicates that the message is expired.
     */
    UAMessageCenterMessageLoadErrorCodeMessageExpired
};

/**
 * The domain for NSErrors generated when loading messages
 */
extern NSString * const UAMessageCenterMessageLoadErrorDomain;

/**
 * The key used for accessing HTTP status codes for UAMessageCenterMessageLoadErrorCodeFailureStatus errors
 */
extern NSString * const UAMessageCenterMessageLoadErrorHTTPStatusKey;

/**
 * Default implementation of a view controller for reading Message Center messages.
 */
NS_SWIFT_NAME(DefaultMessageCenterMessageViewController)
@interface UADefaultMessageCenterMessageViewController : UIViewController

/**
 * The message view delegate.
 */
@property (nonatomic, weak, nullable) id<UAMessageCenterMessageViewDelegate> delegate;

/**
 * The UAInboxMessage being displayed.
 */
@property (nonatomic, readonly, nullable) UAInboxMessage *message;

/**
 * Disables 3D touching and long pressing on links in messages.
 */
@property (nonatomic, assign) BOOL disableMessageLinkPreviewAndCallouts;

- (instancetype)initWithCoder:(NSCoder *)aDecoder NS_UNAVAILABLE;

/**
 * Load a UAInboxMessage by message ID.
 *
 * @param messageID The message ID of the message.
 */
- (void)loadMessageForID:(nullable NSString *)messageID;

/**
 * Clears the message view and shows the default label indicating no message is selected.
 */
- (void)clearMessage;

@end

NS_ASSUME_NONNULL_END

