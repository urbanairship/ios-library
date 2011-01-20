/*
 Copyright 2009-2010 Urban Airship Inc. All rights reserved.

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

#import "UAPush.h"
#import "UA_ASIHTTPRequest.h"
#import "UAirship.h"
#import "UAViewUtils.h"
#import "UAUtils.h"

UA_VERSION_IMPLEMENTATION(UAPushVersion, UA_VERSION)

@implementation UAPush
@synthesize alias, tags, badge, quietTime, tz;

SINGLETON_IMPLEMENTATION(UAPush)

static Class _uiClass;

-(void)dealloc {
    [[UAirship shared] removeObserver:self];
    RELEASE_SAFELY(alias);
    RELEASE_SAFELY(tags);
    RELEASE_SAFELY(quietTime);
    RELEASE_SAFELY(tz);
    [super dealloc];
}

- (id)init {
    self = [super init];
    if (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        alias = [[defaults objectForKey:kAlias] retain];
        tags = [[defaults objectForKey:kTags] retain];
        if (tags == nil) {
            tags = [[NSMutableArray alloc] init];
        }
        quietTime = [[defaults objectForKey:kQuietTime] retain];
        tz = [[defaults objectForKey:kTimeZone] retain];
        badge = [defaults integerForKey:kBadge];

        [[UAirship shared] addObserver:self];
    }
    return self;
}

#pragma mark -
#pragma mark Private methods

- (Class)uiClass {
    if (!_uiClass) {
        _uiClass = NSClassFromString(PUSH_UI_CLASS);
    }
    return _uiClass;
}

- (NSString *)getTagFromUrl:(NSURL *)url {
    return [[url.relativePath componentsSeparatedByString:@"/"] lastObject];
}

- (void)updateRegistrationInfo {
    NSMutableDictionary *body = [NSMutableDictionary dictionary];
    if (alias != nil) {
        [body setObject:alias forKey:@"alias"];
    }
    if (tags != nil && tags.count != 0) {
        [body setObject:tags forKey:@"tags"];
    }
    if (tz != nil && quietTime != nil) {
        [body setObject:tz forKey:@"tz"];
        [body setObject:quietTime forKey:@"quiettime"];
    }
    [body setObject:[NSNumber numberWithInt:badge] forKey:@"badge"];
    [[UAirship shared] registerDeviceTokenWithExtraInfo:body];
}

- (void)saveDefaults {
    UALOG(@"save user defaults, alias: %@; tags: %@; badge: %d, quiettime: %@, tz: %@",
          alias, tags, badge, quietTime, tz);
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:tags forKey:kTags];
    [defaults setObject:alias forKey:kAlias];
    [defaults setInteger:badge forKey:kBadge];
    [defaults setObject:quietTime forKey:kQuietTime];
    [defaults setObject:tz forKey:kTimeZone];
    [defaults synchronize];
}

#pragma mark -
#pragma mark UA Registration Observer methods

- (void)registerDeviceTokenSucceed {
    [self saveDefaults];
}

#pragma mark -
#pragma mark UA Registration callbacks

- (void)addTagToDeviceFailed:(UA_ASIHTTPRequest *)request {
    UALOG(@"Using U/P: %@ / %@", request.username, request.password);
    [UAUtils requestWentWrong:request keyword:@"add tag to current device"];
    [self notifyObservers:@selector(addTagToDeviceFailed:) withObject:[request error]];
}

- (void)addTagToDeviceSucceed:(UA_ASIHTTPRequest *)request {
    if (request.responseStatusCode != 200 && request.responseStatusCode != 201){
        [self addTagToDeviceFailed:request];
    } else {
        UALOG(@"Tag added successfully: %d - %@", request.responseStatusCode, request.url);
        NSString *tag = [self getTagFromUrl:request.url];
        if (![tags containsObject:tag]) {
            [tags addObject:tag];
        }
        [self saveDefaults];
        [self notifyObservers:@selector(addTagToDeviceSucceed)];
    }
}

- (void)removeTagFromDeviceFailed:(UA_ASIHTTPRequest *)request {
    UALOG(@"Using U/P: %@ / %@", request.username, request.password);
    [UAUtils requestWentWrong:request keyword:@"remove tag from current device"];
    [self notifyObservers:@selector(addTagToDeviceFailed:) withObject:[request error]];
}

- (void)removeTagFromDeviceSucceed:(UA_ASIHTTPRequest *)request {
    if (request.responseStatusCode != 204){
        [self removeTagFromDeviceFailed:request];
    } else {
        UALOG(@"Tag removed successfully: %d - %@", request.responseStatusCode, request.url);
        NSString *tag = [self getTagFromUrl:request.url];
        [tags removeObject:tag];
        [self saveDefaults];
        [self notifyObservers:@selector(removeTagFromDeviceSucceed)];
    }
}

#pragma mark -
#pragma mark Open APIs - Property Setters

- (void)setAlias:(NSString *)value {
    [value retain];
    [alias release];
    alias = value;
    [self updateRegistrationInfo];
}

- (void)setTags:(NSMutableArray *)value {
    [value retain];
    [tags release];
    tags = value;
    [self updateRegistrationInfo];
}

- (void)setBadge:(int)value {
    badge = value;
    [self updateRegistrationInfo];
}

- (void)setQuietTimeFrom:(NSDate *)from to:(NSDate *)to withTimeZone:(NSTimeZone *)timezone {
    if (!from || !to || !timezone) {
        UALOG(@"parameter is nil. from: %@ to: %@ timezone: %@", from, to, timezone);
        return;
    }

    NSCalendar *cal = [[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
    NSString *fromStr = [NSString stringWithFormat:@"%d:%02d",
                         [cal components:NSHourCalendarUnit fromDate:from].hour,
                         [cal components:NSMinuteCalendarUnit fromDate:from].minute];
    NSString *toStr = [NSString stringWithFormat:@"%d:%02d",
                       [cal components:NSHourCalendarUnit fromDate:to].hour,
                       [cal components:NSMinuteCalendarUnit fromDate:to].minute];
    self.quietTime = [NSDictionary dictionaryWithObjectsAndKeys:fromStr, @"start",
                      toStr, @"end", nil];
    self.tz = [timezone name];
    [self updateRegistrationInfo];
}

#pragma mark -
#pragma mark Open APIs - Custom UI

+ (void)useCustomUI:(Class)customUIClass {
    _uiClass = customUIClass;
}

#pragma mark -
#pragma mark Open APIs - UI Display

+ (void)openApnsSettings:(UIViewController *)viewController
                animated:(BOOL)animated {
    [[[UAPush shared] uiClass] openApnsSettings:viewController animated:animated];
}

+ (void)openTokenSettings:(UIViewController *)viewController
                 animated:(BOOL)animated {
    [[[UAPush shared] uiClass] openTokenSettings:viewController animated:animated];
}

+ (void)closeApnsSettingsAnimated:(BOOL)animated {
    [[[UAPush shared] uiClass] closeApnsSettingsAnimated:animated];
}

+ (void)closeTokenSettingsAnimated:(BOOL)animated {
    [[[UAPush shared] uiClass] closeTokenSettingsAnimated:animated];
}

#pragma mark -
#pragma mark Open APIs - UA Registration Tags APIs

- (void)addTagToCurrentDevice:(NSString *)tag {
    NSString *urlString = [NSString stringWithFormat:@"%@/api/device_tokens/%@/tags/%@/",
                           [[UAirship shared] server],
                           [[UAirship shared] deviceToken],
                           tag];

    NSURL *url = [NSURL URLWithString:urlString];
    UA_ASIHTTPRequest *request = [UAUtils requestWithURL:url
                                       method:@"PUT"
                                     delegate:self
                                       finish:@selector(addTagToDeviceSucceed:)
                                         fail:@selector(addTagToDeviceFailed:)];
    [request startAsynchronous];
}

- (void)removeTagFromCurrentDevice:(NSString *)tag {
    NSString *urlString = [NSString stringWithFormat:@"%@/api/device_tokens/%@/tags/%@/",
                           [[UAirship shared] server],
                           [[UAirship shared] deviceToken],
                           tag];

    NSURL *url = [NSURL URLWithString:urlString];
    UA_ASIHTTPRequest *request = [UAUtils requestWithURL:url
                                       method:@"DELETE"
                                     delegate:self
                                       finish:@selector(removeTagFromDeviceSucceed:)
                                         fail:@selector(removeTagFromDeviceFailed:)];

    [request startAsynchronous];
}

@end
