//
//  RichPushSender.m
//  InboxSampleLib
//
//  Created by Marc Sciglimpaglia on 3/8/11.
//  Copyright 2011 Urban Airship. All rights reserved.
//

#import "RichPushSender.h"
#import "UA_SBJSON.h"
#import "UA_ASIHTTPRequest.h"
#import "UAUser.h"
#import "UAirship.h"


@implementation RichPushSender

@synthesize buttonTitles, messages;

- (id)init {
	if(self = [super init]) {
		
		self.buttonTitles = [NSArray arrayWithObjects:@"Coupon Demo", @"Pill Demo", @"Voting Demo", @"Concert Demo", nil];
		self.messages = [NSMutableDictionary dictionary];
		
		NSMutableDictionary *couponDictionary = [NSMutableDictionary dictionary];
		
		[couponDictionary setValue:@"New Coupon!" forKey:@"alert"];
		[couponDictionary setValue:@"Important Message" forKey:@"messageTitle"];
		[couponDictionary setValue:@"coupon" forKey:@"filename"];
		
		NSMutableDictionary *pillDictionary = [NSMutableDictionary dictionary];
		
		[pillDictionary setValue:@"You have a Pill Reminder!" forKey:@"alert"];
		[pillDictionary setValue:@"Important Message" forKey:@"messageTitle"];
		[pillDictionary setValue:@"pill" forKey:@"filename"];
		
		NSMutableDictionary *votingDictionary = [NSMutableDictionary dictionary];
		
		[votingDictionary setValue:@"Time to Vote!!" forKey:@"alert"];	
		[votingDictionary setValue:@"Important Message" forKey:@"messageTitle"];
		[votingDictionary setValue:@"vote" forKey:@"filename"];
		
		NSMutableDictionary *concertDictionary = [NSMutableDictionary dictionary];
		
		[concertDictionary setValue:@"Concert Tonight!" forKey:@"alert"];
		[concertDictionary setValue:@"Important Message" forKey:@"messageTitle"];
		[concertDictionary setValue:@"nkor" forKey:@"filename"];
		
		[messages setValue:couponDictionary forKey:@"Coupon Demo"];
		[messages setValue:pillDictionary forKey:@"Pill Demo"];
		[messages setValue:votingDictionary forKey:@"Voting Demo"];
		[messages setValue:concertDictionary forKey:@"Concert Demo"];
		
	}
	
	return self;
}

- (void)sendRichPush:(NSMutableDictionary *)data {
	
	UA_SBJsonWriter *writer = [UA_SBJsonWriter new];
    NSString* body = [writer stringWithObject:data];
    [writer release];
	
	
	NSMutableDictionary *config;
    NSString *configPath = [[NSBundle mainBundle] pathForResource:@"AirshipConfig" ofType:@"plist"];
	config = [[[NSMutableDictionary alloc] initWithContentsOfFile:configPath] autorelease];
	
	NSString *masterSecret = [config objectForKey:@"DEVELOPMENT_MASTER_SECRET"];
	
	NSLog(@"Master secret: %@", masterSecret);
	
	//inline dirtiness
	
	NSString *urlString = [NSString stringWithFormat:@"%@%@",
                           [[UAirship shared] server],
                           @"/api/airmail/send/"];
	
	NSLog(@"urlString: %@", urlString);
	
    UA_ASIHTTPRequest *request = [UA_ASIHTTPRequest requestWithURL:[NSURL URLWithString:urlString]];
    [request setRequestMethod:@"POST"];
    request.username = [UAirship shared].appId;
    request.password = masterSecret;
    //request.delegate = self;
    request.timeOutSeconds = 60;
    //[request setDidFinishSelector:finishSelector];
    //[request setDidFailSelector:failSelector];
	
    [request addRequestHeader:@"Content-Type" value:@"application/json"];
    [request appendPostData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    [request startAsynchronous];
	
	//end inline dirtiness
	
	
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)index {	
	
	NSMutableDictionary *payload = [messages valueForKey:[buttonTitles objectAtIndex:index-1]];
	
	//NSLog(@"%@", [payload description]);
	
    NSMutableDictionary *data = [NSMutableDictionary dictionary];
	
	NSMutableDictionary *aps = [NSMutableDictionary dictionary];
	[aps setValue:[payload objectForKey:@"alert"] forKey:@"alert"];
	
	NSMutableDictionary *push = [NSMutableDictionary dictionary];
	[push setValue:aps forKey:@"aps"];
	
	[data setValue:push forKey:@"push"];
	
	[data setValue:[NSArray arrayWithObjects:[UAUser defaultUser].username, nil] forKey:@"users"];
	
	[data setValue:[payload objectForKey:@"messageTitle"] forKey:@"title"];
	
	NSString *filePath = [[NSBundle mainBundle] pathForResource:[payload objectForKey:@"filename"] ofType:@"html"];
	NSString *message = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
	
	[data setValue:message forKey:@"message"];
	
	[self sendRichPush:data];
    	
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)index {
}

- (void)dealloc {
	self.messages = nil;
	self.buttonTitles = nil;
	[super dealloc];
}
	
@end
