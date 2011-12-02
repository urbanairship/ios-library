
#import <Foundation/Foundation.h>

typedef enum {
    UALocalStorageTypeCritical = 0,
    UALocalStorageTypeCached = 1,
    UALocalStorageTypeTemporary = 2,
    UALocalStorageTypeOffline = 3
} UALocalStorageType;

@interface UALocalStorageDirectory : NSObject {
    UALocalStorageType storageType;
    NSString *subpath;
    NSSet *oldPaths; //of NSString
}

+ (UALocalStorageDirectory *)uaDirectory;
+ (UALocalStorageDirectory *)downloadsDirectory;

+ (UALocalStorageDirectory *)localStorageDirectoryWithType:(UALocalStorageType)storageType withSubpath:(NSString *)nameString withOldPaths:(NSSet *)oldPathsSet;

@property(nonatomic, assign) UALocalStorageType storageType;
@property(nonatomic, copy) NSString *subpath;
@property(nonatomic, retain) NSSet *oldPaths;
@property(nonatomic, readonly) NSString *path;

@end
