/* Copyright Airship and Contributors */

#import "UAAirshipBaseTest.h"
#import "UAChannelCapture+Internal.h"
#import "UAChannel.h"
#import "UARuntimeConfig.h"
#import "AirshipTests-Swift.h"

@import AirshipCore;

@interface UAChannelCaptureTest : UAAirshipBaseTest
@property(nonatomic, strong) UAChannelCapture *channelCapture;
@property(nonatomic, strong) NSString *testChannelID;

@property(nonatomic, strong) id mockChannel;
@property(nonatomic, strong) id mockPasteboard;
@property(nonatomic, strong) NSArray<NSDictionary<NSString *,id> *> *mockItems;
@property(nonatomic, strong) NSNotificationCenter *notificationCenter;
@property(nonatomic, strong) UATestDate *testDate;

@end

@implementation UAChannelCaptureTest

- (void)setUp {
    [super setUp];

    self.testChannelID = @"pushChannelID";
    
    self.mockChannel = [self mockForClass:[UAChannel class]];
    [[[self.mockChannel stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:&self->_testChannelID];
    }] identifier];

    self.notificationCenter = [[NSNotificationCenter alloc] init];

    self.testDate = [[UATestDate alloc] initWithOffset:0 dateOverride:[NSDate date]];

    self.config.channelCaptureEnabled = YES;
    
    self.mockItems = [NSMutableArray array];

    [self createChannelCapture];
}

- (void)expectMockPasteboardToBeSet:(BOOL)expectSet {
    self.mockPasteboard = [self mockForClass:[UIPasteboard class]];
    
    [[[self.mockPasteboard stub] andDo:^(NSInvocation *invocation) {
        [invocation setReturnValue:&self->_mockItems];
    }] items];
    
    if (expectSet) {
        [[self.mockPasteboard expect] setItems:[OCMArg checkWithBlock:^BOOL(id obj) {
            if (![obj isKindOfClass:[NSArray class]]) {
                return NO;
            }
            
            NSArray *items = (NSArray *)obj;
            if (items.count != 1) {
                return NO;
            }
            if (![items[0] isKindOfClass:[NSDictionary class]]) {
                return NO;
            }
            
            NSDictionary *item = (NSDictionary *)items[0];
            if (item.allKeys.count != 1) {
                return NO;
            }
            if (item.allKeys[0] != UIPasteboardTypeAutomatic) {
                return NO;
            }
            if (![item.allValues[0] isKindOfClass:[NSString class]]) {
                return NO;
            }
            
            NSString *pasteboard = (NSString *)item.allValues[0];
            self.mockItems = [items copy];
            
            NSString *expectedPasteboard = (self.testChannelID) ? [NSString stringWithFormat:@"ua:%@", self.testChannelID] : @"ua:";
            return [pasteboard isEqualToString:expectedPasteboard];
        }] options:[OCMArg checkWithBlock:^BOOL(id obj) {
            if (![obj isKindOfClass:[NSDictionary class]]) {
                return NO;
            }
            
            NSDictionary *option = (NSDictionary *)obj;
            if (option.allKeys.count != 1) {
                return NO;
            }
            if (option.allKeys[0] != UIPasteboardOptionExpirationDate) {
                return NO;
            }
            if (![option.allValues[0] isKindOfClass:[NSDate class]]) {
                return NO;
            }
            
            NSDate *expirationDate = (NSDate *)option.allValues[0];
            if ([expirationDate timeIntervalSinceDate:[self.testDate now]] != 60) {
                return NO;
            }
            
            return YES;
        }]];
    } else {
        [[self.mockPasteboard reject] setString:OCMOCK_ANY];
        [[self.mockPasteboard reject] setItems:OCMOCK_ANY options:OCMOCK_ANY];
    }
    
    [[self.mockPasteboard stub] setItems:[OCMArg checkWithBlock:^BOOL(id obj) {
        if (!obj) {
            return NO;
        }
        
        if (![obj isKindOfClass:[NSArray class]]) {
            return NO;
        }
        
        self.mockItems = [(NSArray *)obj copy];

        return YES;
    }]];
     
    [[[self.mockPasteboard stub] andReturn:self.mockPasteboard] generalPasteboard];
}

- (void)createChannelCapture {
    self.channelCapture =  [UAChannelCapture channelCaptureWithConfig:self.config
                                                              channel:self.mockChannel
                                                            dataStore:self.dataStore
                                                   notificationCenter:self.notificationCenter
                                                                 date:self.testDate];
}

/**
 * Test channel captured when enabled in the config.
 */
- (void)testChannelCapturedWhenEnabledViaConfig {
    [self verifyChannelIsCapturedAfterKnocks];
}

/**
 * Test channel is not captured when disabled in the config.
 */
- (void)testChannelNotCapturedWhenDisabledViaConfig {
    self.config.channelCaptureEnabled = NO;
    [self createChannelCapture];

    [self verifyChannelIsNotCapturedAfterKnocks];
}

/**
 * Test disabling channel capture.
 */
- (void)testDisable {
    self.channelCapture.enabled = NO;
    [self verifyChannelIsNotCapturedAfterKnocks];
}

/**
 * Test enabling channel capture.
 */
- (void)testEnable {
    self.channelCapture.enabled = YES;
    [self verifyChannelIsCapturedAfterKnocks];
}

/**
 * Test disabling channel capture twice.
 */
- (void)testDisableTwice {
    self.channelCapture.enabled = NO;
    [self verifyChannelIsNotCapturedAfterKnocks];

    self.channelCapture.enabled = NO;
    [self verifyChannelIsNotCapturedAfterKnocks];
}

/**
 * Test enabling channel capture after disabling.
 */
- (void)testEnableAfterDisable {
    [self.channelCapture setEnabled:NO];
    [self verifyChannelIsNotCapturedAfterKnocks];
    
    [self.channelCapture setEnabled:YES];
    [self verifyChannelIsCapturedAfterKnocks];
}

/**
 * Test enabling channel capture with config disabled.
 */
- (void)testEnableWhenDisabledInConfig {
    self.config.channelCaptureEnabled = NO;
    [self createChannelCapture];

    [self verifyChannelIsNotCapturedAfterKnocks];
    
    [self.channelCapture setEnabled:YES];
    [self verifyChannelIsCapturedAfterKnocks];
}


/**
 * Test channel captured when there have been non-knock foregrounds
 */
- (void)testChannelCapturedByKnocksAfterNonKnockForegrounds {
    // Add a couple of old foregrounds to simulate app-has-been-running state
    [self knock:2];
    self.testDate.offset += 30;
    [self verifyChannelIsCapturedAfterKnocks];
}

/**
 * Test channel capture tool does not write to pasteboard if knocks take too long
 */
- (void)testChanneNotCapturedWhenKnocksTakeTooLong {
    [self verifyChannelIsCapturedAfterKnocks];
    [self verifyChannelIsNotCapturedWhenKnocksTakeTooLong];
}

/**
  * Test no channel id
 */
- (void)testNoChannelId {
    self.testChannelID = nil;
    
    [self verifyChannelIsCapturedAfterKnocks];
}

/**
 * Helper method to verify channel capture is captured
 */
- (void)verifyChannelIsCapturedAfterKnocks {
    // The pasteboard should not be set during the first 5 knocks
    [self expectMockPasteboardToBeSet:NO];

    [self knock:5];

    [self.mockPasteboard verify];
    
    // The pasteboard should be set during the sixth knock
    [self expectMockPasteboardToBeSet:YES];

    [self knock];

    [self.mockPasteboard verify];
}

/**
 * Helper method to verify channel is not captured
 */
- (void)verifyChannelIsNotCapturedAfterKnocks {
    [self expectMockPasteboardToBeSet:NO];

    [self knock:6];
    
    [self.mockPasteboard verify];
}

/**
 * Helper method to verify channel is not captured when knocks take too long
 */
- (void)verifyChannelIsNotCapturedWhenKnocksTakeTooLong {
    [self expectMockPasteboardToBeSet:NO];

    [self knock];

    self.testDate.offset += 30;
    
    [self knock:5];
    
    [self.mockPasteboard verify];
}

/**
* Helper method to simulate a knock
*/
- (void)knock {
    self.testDate.offset += 1;
    [self.notificationCenter postNotificationName:UAAppStateTracker.didTransitionToForeground object:nil];
}

/**
* Helper method to simulate multiple knocks
*/
- (void)knock:(NSUInteger)repeat {
    for (NSUInteger i = 0; i < repeat; i++) {
        [self knock];
    }
}

@end

