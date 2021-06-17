/* Copyright Airship and Contributors */

#import "UABaseTest.h"
#import <CoreData/CoreData.h>
#import "UAirship.h"
#import "NSJSONSerialization+UAAdditions.h"
#import "UAScheduleDataMigrator+Internal.h"
#import "UAScheduleData+Internal.h"
#import "UAAutomationStore+Internal.h"

@interface UAScheduleDataMigratorTest : UABaseTest
@property (nonatomic, strong) NSManagedObjectContext *managedContext;
@end

@implementation UAScheduleDataMigratorTest

- (void)setUp {
    [super setUp];

    NSBundle *bundle = [NSBundle bundleForClass:[UAAutomationStore class]];
    NSURL *modelURL = [bundle URLForResource:@"UAAutomation" withExtension:@"momd"];

    NSManagedObjectModel *mom = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    NSPersistentStoreCoordinator *psc = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [moc setPersistentStoreCoordinator:psc];
    self.managedContext = moc;

    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption : @YES,
                               NSInferMappingModelAutomaticallyOption : @YES };
    [self.managedContext.persistentStoreCoordinator addPersistentStoreWithType:NSInMemoryStoreType
                                                                 configuration:nil
                                                                           URL:nil
                                                                       options:options
                                                                         error:nil];
}

- (void)tearDown {
    [self.managedContext reset];
    [self.managedContext.persistentStoreCoordinator removePersistentStore:self.managedContext.persistentStoreCoordinator.persistentStores[0] error:nil];
    self.managedContext.persistentStoreCoordinator = nil;
    [super tearDown];
}

/**
 * Migrates duration from milliseconds to seconds
 */
- (void)testMigrationFromVersion0 {
    id old =  @{
        @"display_type":@"banner",
        @"display":@{
                @"duration":@30001
        }
    };

    id expectedData = @{
        @"display_type":@"banner",
        @"display":@{
                @"duration":@30.001
        }
    };

    UAScheduleData *scheduleData = [NSEntityDescription insertNewObjectForEntityForName:@"UAScheduleData"
                                                                 inManagedObjectContext:self.managedContext];
    scheduleData.data = [NSJSONSerialization stringWithObject:old];
    scheduleData.dataVersion = @(0);
    [UAScheduleDataMigrator migrateSchedules:@[scheduleData]];

    NSDictionary *migratedData = [NSJSONSerialization objectWithString:scheduleData.data];
    XCTAssertEqualObjects(expectedData, migratedData);
    XCTAssertEqual(UAScheduleDataVersion, [scheduleData.dataVersion intValue]);
}

/**
 * Migrates source to remote-data if set to app-defined
 */
- (void)testMigrationFromVersion1 {
    id old =  @{
        @"display_type":@"banner",
        @"display":@{},
        @"source":@"app-defined"
    };

    id expectedData = @{
        @"display_type":@"banner",
        @"display":@{},
        @"source": @"remote-data"
    };

    UAScheduleData *scheduleData = [NSEntityDescription insertNewObjectForEntityForName:@"UAScheduleData"
                                                                 inManagedObjectContext:self.managedContext];
    scheduleData.data = [NSJSONSerialization stringWithObject:old];
    scheduleData.dataVersion = @(0);
    [UAScheduleDataMigrator migrateSchedules:@[scheduleData]];

    NSDictionary *migratedData = [NSJSONSerialization objectWithString:scheduleData.data];
    XCTAssertEqualObjects(expectedData, migratedData);
    XCTAssertEqual(UAScheduleDataVersion, [scheduleData.dataVersion intValue]);
}

/**
 * Migrates type to actions if the payload data does not define an in-app message.
 */
- (void)testMigrationFromVersion2TypeActions {
    id actions = @{
        @"foo":@"bar",
    };

    UAScheduleData *scheduleData = [NSEntityDescription insertNewObjectForEntityForName:@"UAScheduleData"
                                                                 inManagedObjectContext:self.managedContext];
    scheduleData.data = [NSJSONSerialization stringWithObject:actions];
    scheduleData.dataVersion = @(0);
    [UAScheduleDataMigrator migrateSchedules:@[scheduleData]];

    XCTAssertEqualObjects(actions, [NSJSONSerialization objectWithString:scheduleData.data]);
    XCTAssertNotNil(scheduleData.type);
    XCTAssertEqual(UAScheduleTypeActions, [scheduleData.type intValue]);
    XCTAssertEqual(UAScheduleDataVersion, [scheduleData.dataVersion intValue]);
}

/**
 * Migrates type to message if the payload defines display and display_type
 */
- (void)testMigrationFromVersion2TypeMessage{
    id message = @{
        @"display_type":@"banner",
        @"display":@{},
    };

    UAScheduleData *scheduleData = [NSEntityDescription insertNewObjectForEntityForName:@"UAScheduleData"
                                                                 inManagedObjectContext:self.managedContext];
    scheduleData.data = [NSJSONSerialization stringWithObject:message];
    scheduleData.dataVersion = @(0);
    [UAScheduleDataMigrator migrateSchedules:@[scheduleData]];

    XCTAssertEqualObjects(message, [NSJSONSerialization objectWithString:scheduleData.data]);
    XCTAssertEqual(UAScheduleTypeInAppMessage, [scheduleData.type intValue]);
    XCTAssertEqual(UAScheduleDataVersion, [scheduleData.dataVersion intValue]);
}


/**
 * Migrates audience if the in-app message contains the audience.
 */
- (void)testMigrationFromVersion2Audience {
    id old =  @{
        @"display_type":@"banner",
        @"display":@{},
        @"audience": @{ @"whatever": @"cool" }
    };

    id expected =  @{
        @"display_type":@"banner",
        @"display":@{},
    };

    // Add the old version of the data
    UAScheduleData *scheduleData = [NSEntityDescription insertNewObjectForEntityForName:@"UAScheduleData"
                                                                 inManagedObjectContext:self.managedContext];
    scheduleData.data = [NSJSONSerialization stringWithObject:old];
    scheduleData.dataVersion = @(0);
    [UAScheduleDataMigrator migrateSchedules:@[scheduleData]];

    XCTAssertEqualObjects(expected, [NSJSONSerialization objectWithString:scheduleData.data]);
    XCTAssertEqualObjects(old[@"audience"], [NSJSONSerialization objectWithString:scheduleData.audience]);
    XCTAssertEqual(UAScheduleTypeInAppMessage, [scheduleData.type intValue]);
    XCTAssertEqual(UAScheduleDataVersion, [scheduleData.dataVersion intValue]);
}

/**
 * Migrates the group as the ID if the source is legacy-push.
 */
- (void)testMigrationFromVersion2IDSourceLegacy {
    id message =  @{
        @"display_type":@"banner",
        @"display":@{},
        @"source": @"legacy-push",
    };

    // Add the old version of the data
    UAScheduleData *scheduleData = [NSEntityDescription insertNewObjectForEntityForName:@"UAScheduleData"
                                                                 inManagedObjectContext:self.managedContext];
    scheduleData.data = [NSJSONSerialization stringWithObject:message];
    scheduleData.dataVersion = @(0);
    scheduleData.identifier = @"some ID";
    scheduleData.group = @"some Group";
    [UAScheduleDataMigrator migrateSchedules:@[scheduleData]];

    XCTAssertEqualObjects(message, [NSJSONSerialization objectWithString:scheduleData.data]);
    XCTAssertEqualObjects(@"some Group", scheduleData.group);
    XCTAssertEqualObjects(@"some Group", scheduleData.identifier);
    XCTAssertEqual(UAScheduleTypeInAppMessage, [scheduleData.type intValue]);
    XCTAssertEqual(UAScheduleDataVersion, [scheduleData.dataVersion intValue]);
}

/**
 * Migrates the group as the ID if the source is remote-data.
 */
- (void)testMigrationFromVersion2IDSourceRemoteData {
    id message =  @{
        @"display_type":@"banner",
        @"display":@{},
        @"source": @"remote-data",
    };

    // Add the old version of the data
    UAScheduleData *scheduleData = [NSEntityDescription insertNewObjectForEntityForName:@"UAScheduleData"
                                                                 inManagedObjectContext:self.managedContext];
    scheduleData.data = [NSJSONSerialization stringWithObject:message];
    scheduleData.dataVersion = @(0);
    scheduleData.identifier = @"some ID";
    scheduleData.group = @"some Group";
    [UAScheduleDataMigrator migrateSchedules:@[scheduleData]];

    XCTAssertEqualObjects(message, [NSJSONSerialization objectWithString:scheduleData.data]);
    XCTAssertEqualObjects(@"some Group", scheduleData.group);
    XCTAssertEqualObjects(@"some Group", scheduleData.identifier);
    XCTAssertEqual(UAScheduleTypeInAppMessage, [scheduleData.type intValue]);
    XCTAssertEqual(UAScheduleDataVersion, [scheduleData.dataVersion intValue]);
}

/**
 * Migrates and uniques the group as the ID if the source is app-defined.
 */
- (void)testMigrationFromVersion2IDSourceAppDefined {
    id messageFoo =  @{
        @"display_type":@"banner",
        @"display":@{},
        @"source": @"app-defined",
    };

    id messageFooTwo =  @{
        @"display_type":@"custom",
        @"display":@{},
        @"source": @"app-defined",
    };

    // Add the old version of the data
    UAScheduleData *foo = [NSEntityDescription insertNewObjectForEntityForName:@"UAScheduleData"
                                                                 inManagedObjectContext:self.managedContext];
    foo.data = [NSJSONSerialization stringWithObject:messageFoo];
    foo.dataVersion = @(2);
    foo.identifier = @"some ID";
    foo.group = @"foo";

    // Add the old version of the data
    UAScheduleData *fooTwo = [NSEntityDescription insertNewObjectForEntityForName:@"UAScheduleData"
                                                          inManagedObjectContext:self.managedContext];
    fooTwo.data = [NSJSONSerialization stringWithObject:messageFooTwo];
    fooTwo.dataVersion = @(2);
    fooTwo.identifier = @"some other ID";
    fooTwo.group = @"foo";
    fooTwo.metadata = [NSJSONSerialization stringWithObject:@{@"neat": @"story"}];

    [UAScheduleDataMigrator migrateSchedules:@[foo, fooTwo]];

    id expectedFooMetadata = @{
        @"com.urbanairship.original_schedule_id": @"some ID",
        @"com.urbanairship.original_message_id": @"foo"
    };

    XCTAssertEqualObjects(expectedFooMetadata, [NSJSONSerialization objectWithString:foo.metadata]);
    XCTAssertEqualObjects(messageFoo, [NSJSONSerialization objectWithString:foo.data]);
    XCTAssertEqualObjects(@"foo", foo.identifier);

    id expectedFooTwoMetadata = @{
        @"com.urbanairship.original_schedule_id": @"some other ID",
        @"com.urbanairship.original_message_id": @"foo",
        @"neat": @"story"
    };

    XCTAssertEqualObjects(expectedFooTwoMetadata, [NSJSONSerialization objectWithString:fooTwo.metadata]);
    XCTAssertEqualObjects(messageFooTwo, [NSJSONSerialization objectWithString:fooTwo.data]);
    XCTAssertEqualObjects(@"foo#1", fooTwo.identifier);
}

@end
