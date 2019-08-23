/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import <CoreData/CoreData.h>
#import "UAirship.h"
#import "NSManagedObjectContext+UAAdditions+Internal.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAScheduleDataMigrator+Internal.h"
#import "UAScheduleData+Internal.h"

@interface UAScheduleDataMigratorTest : UABaseTest
@property (nonatomic, strong) NSManagedObjectContext *managedContext;
@end

@implementation UAScheduleDataMigratorTest

- (void)setUp {
    [super setUp];

    NSURL *modelURL = [[UAirship resources] URLForResource:@"UAAutomation" withExtension:@"momd"];
    self.managedContext = [NSManagedObjectContext managedObjectContextForModelURL:modelURL
                                                                  concurrencyType:NSPrivateQueueConcurrencyType];

    [self.managedContext addPersistentInMemoryStore:@"Test" completionHandler:^(BOOL result, NSError *error) {}];
}

- (void)tearDown {
    [self.managedContext reset];
    [self.managedContext.persistentStoreCoordinator removePersistentStore:self.managedContext.persistentStoreCoordinator.persistentStores[0] error:nil];
    self.managedContext.persistentStoreCoordinator = nil;
    [super tearDown];
}

- (void)testMigration0To1 {
    [self executeTestFromVersion:0 toVersion:1 originalData:@[[self originalDataFor0To1]] expectedData:@[[self expectedDataFor0To1]]];
}

- (NSDictionary *)originalDataFor0To1 {
    return @{
             @"display_type":@"banner",
             @"display":@{
                     @"duration":@30001
                     }
             };
}

- (NSDictionary *)expectedDataFor0To1 {
    return @{
             @"display_type":@"banner",
             @"display":@{
                     @"duration":@30.001
                     }
             };
}

- (void)testMigration1To2 {
    [self executeTestFromVersion:1 toVersion:2 originalData:[self originalDataFor1To2] expectedData:[self expectedDataFor1To2]];
}

- (NSArray<NSDictionary *> *)originalDataFor1To2 {
    // test all three different source types
    return @[
             @{
                 @"source":@"app-defined",
                 @"display_type":@"banner",
                 @"message_id":@"a0740f54-7686-46e7-b6d2-ef69a41f5b96"
                 },
             @{
                 @"source":@"legacy-push",
                 @"display_type":@"banner",
                 @"message_id":@"aaaaaaaa-d425-44ad-8ff8-fcabf7ece227"
                 },
             @{
                 @"source":@"remote-data",
                 @"display_type":@"modal",
                 @"message_id":@"abcdefef-d425-44ad-8ff8-fcabf7ece227"
                 }
             ];
}

- (NSArray<NSDictionary *> *)expectedDataFor1To2 {
    // test all three different source types
    return @[
             @{
                 @"source":@"remote-data",
                 @"display_type":@"banner",
                 @"message_id":@"a0740f54-7686-46e7-b6d2-ef69a41f5b96"
                 },
             @{
                 @"source":@"legacy-push",
                 @"display_type":@"banner",
                 @"message_id":@"aaaaaaaa-d425-44ad-8ff8-fcabf7ece227"
                 },
             @{
                 @"source":@"remote-data",
                 @"display_type":@"modal",
                 @"message_id":@"abcdefef-d425-44ad-8ff8-fcabf7ece227"
                 }
             ];
}

- (void)testMigration0To2 {
    [self executeTestFromVersion:0 toVersion:2 originalData:[self originalDataFor0To2] expectedData:[self expectedDataFor0To2]];
}

- (NSArray<NSDictionary *> *)originalDataFor0To2 {
    NSMutableArray *data = [NSMutableArray array];
    
    [data addObject:[self originalDataFor0To1]];
    [data addObjectsFromArray:[self originalDataFor1To2]];
    [data addObject:@{
                      @"source":@"app-defined",
                      @"display_type":@"banner",
                      @"message_id":@"message-id",
                      @"display":@{
                              @"duration":@29999
                              }
                      }
     ];

    return data;
}

- (NSArray<NSDictionary *> *)expectedDataFor0To2 {
    NSMutableArray *data = [NSMutableArray array];
    
    [data addObject:[self expectedDataFor0To1]];
    [data addObjectsFromArray:[self expectedDataFor1To2]];
    [data addObject:@{
                      @"source":@"remote-data",
                      @"display_type":@"banner",
                      @"message_id":@"message-id",
                      @"display":@{
                              @"duration":@(29.999)
                              }
                      }
     ];

    return data;
}

- (void)executeTestFromVersion:(NSUInteger)fromVersion toVersion:(NSUInteger)toVersion originalData:(NSArray<NSDictionary *> *)originalData expectedData:(NSArray<NSDictionary *> *)expectedData {
    XCTAssertEqual(originalData.count, expectedData.count);
    for (NSUInteger index = 0; index < originalData.count; index++) {
        // Add the old version of the data
        UAScheduleData *scheduleData = [NSEntityDescription insertNewObjectForEntityForName:@"UAScheduleData"
                                                                     inManagedObjectContext:self.managedContext];
        scheduleData.data = [NSJSONSerialization stringWithObject:originalData[index]];
        scheduleData.dataVersion = @(fromVersion);
        
        // Migrate
        [UAScheduleDataMigrator migrateScheduleData:scheduleData
                                         oldVersion:fromVersion
                                         newVersion:toVersion];
        
        // Verify the duration was migrated
        XCTAssertEqual(toVersion, [scheduleData.dataVersion unsignedIntegerValue]);
        NSDictionary *migratedData = [NSJSONSerialization objectWithString:scheduleData.data];
        XCTAssertEqualObjects(expectedData[index], migratedData);
    }
}

@end
