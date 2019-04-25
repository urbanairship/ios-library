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
    NSDictionary *oldData = @{
                              @"display_type":@"banner",
                              @"display":@{
                                      @"duration":@30001
                                      }
                              };

    NSDictionary *expected = @{
                               @"display_type":@"banner",
                               @"display":@{
                                       @"duration":@30.001
                                       }
                               };

    // Add the old version of the data
    UAScheduleData *scheduleData = [NSEntityDescription insertNewObjectForEntityForName:@"UAScheduleData"
                                                                 inManagedObjectContext:self.managedContext];
    scheduleData.data = [NSJSONSerialization stringWithObject:oldData];
    scheduleData.dataVersion = @(0);

    // Migrate
    [UAScheduleDataMigrator migrateScheduleData:scheduleData
                                     oldVersion:0
                                     newVersion:1];

    // Verify the duration was migrated
    XCTAssertEqual(1, [scheduleData.dataVersion unsignedIntegerValue]);
    NSDictionary *migratedData = [NSJSONSerialization objectWithString:scheduleData.data];
    XCTAssertEqualObjects(expected, migratedData);
}
@end
