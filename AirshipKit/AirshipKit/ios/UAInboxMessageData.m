/* Copyright Urban Airship and Contributors */

#import "UAInboxMessageData+Internal.h"

/*
 * Implementation
 */
@implementation UAInboxMessageData

@dynamic title;
@dynamic messageBodyURL;
@dynamic messageSent;
@dynamic messageExpiration;
@dynamic unread;
@dynamic unreadClient;
@dynamic deletedClient;
@dynamic messageURL;
@dynamic messageID;
@dynamic extra;
@dynamic rawMessageObject;


@synthesize contentType;

- (BOOL)isGone{
    return ![self.managedObjectContext existingObjectWithID:self.objectID error:NULL];
}
@end
