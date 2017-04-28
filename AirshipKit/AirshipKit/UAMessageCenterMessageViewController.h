/* Copyright 2017 Urban Airship and Contributors */

#import <WebKit/WebKit.h>

@class UAInboxMessage;
@class UADefaultMessageCenterStyle;

/**
 * Default implementation of a view controller for reading Message Center messages.
 */
@interface UAMessageCenterMessageViewController : UIViewController 

///---------------------------------------------------------------------------------------
/// @name Message Center Message View Controller Properties
///---------------------------------------------------------------------------------------

/**
 * The UAInboxMessage being displayed.
 */
@property (nonatomic, strong) UAInboxMessage *message;

/** 
 * An optional predicate for filtering messages.
 */
@property (nonatomic, strong) NSPredicate *filter;

/**
 * Block that will be invoked when this class receives a closeWindow message from the webView.
 */
@property (nonatomic, copy) void (^closeBlock)(BOOL animated);

///---------------------------------------------------------------------------------------
/// @name Message Center Message View Controller Core Methods
///---------------------------------------------------------------------------------------

/**
 * Load a UAInboxMessage at a particular index in the message list.
 * @param index The corresponding index in the message list as an integer.
 */
- (void)loadMessageAtIndex:(NSUInteger)index;

/**
 * Load a UAInboxMessage by message ID.
 * @param mid The message ID as an NSString.
 */
- (void)loadMessageForID:(NSString *)mid;

@end
