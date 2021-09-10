/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import "UATagGroupsLookupResponse+Internal.h"

#if __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#elif __has_include("Airship-Swift.h")
#import "Airship-Swift.h"
#else
@import AirshipCore;
#endif

@interface UATagGroupsLookupResponseTest : UABaseTest
@property(nonatomic, strong) UATagGroupsLookupResponse *response;
@end

@implementation UATagGroupsLookupResponseTest

- (void)setUp {
    [super setUp];

    NSDictionary *tags = @{ @"foo" : [NSSet setWithArray:@[@"baz", @"boz"]], @"bar" : [NSSet setWithArray:@[@"biz"]] };
    UATagGroups *tagGroups = [UATagGroups tagGroupsWithTags:tags];
    self.response = [UATagGroupsLookupResponse responseWithTagGroups:tagGroups status:200 lastModifiedTimestamp:@"2018-03-02T22:56:09"];
}

- (void)testResponseWithJSON {
    NSDictionary *tagsDictionary = @{ @"foo" : @[@"baz", @"boz"], @"bar" : @[@"biz"] };
    NSDictionary *jsonDictionary = @{@"tag_groups" : tagsDictionary, @"last_modified" : @"2018-03-02T22:56:09" };
    UATagGroupsLookupResponse *responseFromJSON = [UATagGroupsLookupResponse responseWithJSON:jsonDictionary status:200];

    XCTAssertEqualObjects(responseFromJSON.tagGroups, self.response.tagGroups);
    XCTAssertEqualObjects(responseFromJSON.lastModifiedTimestamp, self.response.lastModifiedTimestamp);
    XCTAssertEqual(responseFromJSON.status, self.response.status);
}

- (void)testCoding {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.response];
    UATagGroupsLookupResponse *decoded = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    XCTAssertEqualObjects(decoded.tagGroups, self.response.tagGroups);
    XCTAssertEqualObjects(decoded.lastModifiedTimestamp, self.response.lastModifiedTimestamp);
    XCTAssertEqual(decoded.status, self.response.status);
}

@end
