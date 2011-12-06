
#import "UALocalStorageDirectory.h"
#import <sys/xattr.h>

@interface UALocalStorageDirectory()

- (id)initWithStorageType:(UALocalStorageType)type withSubpath:(NSString *)subpathString withOldPaths:(NSSet *)oldPathsSet;
- (void)createIfNecessary;
- (void)migratePath:(NSString *)oldPath;
- (void)setFileAttributes;

@end

@implementation UALocalStorageDirectory

@synthesize storageType;
@synthesize subpath;
@synthesize oldPaths;

+ (UALocalStorageDirectory *)uaDirectory {
    NSString *oldPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask, YES)
                          objectAtIndex:0] stringByAppendingPathComponent: @"/ua"];
    NSString *cachesPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory,NSUserDomainMask, YES)
                          objectAtIndex:0] stringByAppendingPathComponent: @"/Caches/ua"];
    NSSet *pathsSet = [NSMutableSet setWithObjects:oldPath, cachesPath, nil];
    
    return [UALocalStorageDirectory localStorageDirectoryWithType:UALocalStorageTypeOffline withSubpath:@"/ua" withOldPaths:pathsSet];
}

+ (UALocalStorageDirectory *)downloadsDirectory {
    NSString *oldPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) 
                          objectAtIndex:0] stringByAppendingPathComponent: @"/ua/downloads"];

    NSString *cachesPath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) 
                          objectAtIndex:0] stringByAppendingPathComponent: @"/Caches/ua/downloads"];
    NSSet *pathsSet = [NSMutableSet setWithObjects:oldPath, cachesPath, nil];    
    
    return [UALocalStorageDirectory localStorageDirectoryWithType:UALocalStorageTypeOffline withSubpath:@"/ua/downloads" withOldPaths:pathsSet];
}

+ (UALocalStorageDirectory *)localStorageDirectoryWithType:(UALocalStorageType)storageType withSubpath:(NSString *)subpathString withOldPaths:(NSSet *)oldPathsSet {
    return [[[UALocalStorageDirectory alloc] initWithStorageType:storageType withSubpath:subpathString withOldPaths:oldPathsSet] autorelease];
}

- (id)initWithStorageType:(UALocalStorageType)type withSubpath:(NSString *)subpathString withOldPaths:(NSSet *)oldPathsSet {
    if (self = [super init]) {
        self.subpath = subpathString;
        self.storageType = type;
        self.oldPaths = oldPathsSet;
        
        [self createIfNecessary];
    }
    
    return self;
}

- (NSString *)path {
    NSString *root;
    
    switch (storageType) {
        case UALocalStorageTypeCritical:
            root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) 
                    objectAtIndex:0];
            break;
        case UALocalStorageTypeCached:
            root = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) 
                     objectAtIndex:0] stringByAppendingPathComponent:@"/Caches"];
            break;
        case UALocalStorageTypeTemporary:
            root = NSTemporaryDirectory();
            break;
        case UALocalStorageTypeOffline:
            if ([[[UIDevice currentDevice] systemVersion] isEqualToString:@"5.0"]) {
                //we don't have the "do not back up" attribute yet but iCloud
                //will still try to back up anything that is not in Library/Caches
                root = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) 
                         objectAtIndex:0] stringByAppendingPathComponent:@"/Caches"];
                
            } else {
                root = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) objectAtIndex:0];
            }
            break;
        default:
            break;
    }
    
    return [root stringByAppendingPathComponent:subpath];
}

- (void)createIfNecessary {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    //create the directory on disk if needed
    if (![fm fileExistsAtPath:self.path]) {
        [fm createDirectoryAtPath:self.path withIntermediateDirectories:YES attributes:nil error:nil];
        
        [self setFileAttributes];
    }
        
    //migrate old path to new if present and non-equal
    for (NSString *p in oldPaths.allObjects) {
        if ([fm fileExistsAtPath:p] && ![self.path isEqualToString:p]) {
            [self migratePath:p];
        }
    }
}

- (void)migratePath:(NSString *)oldPath {
    NSString *_path = self.path;
    NSFileManager *fm = [NSFileManager defaultManager];
    if ([fm fileExistsAtPath:oldPath]) {
        //move subpaths
        for (NSString *sub in [fm subpathsAtPath:oldPath]) {
            NSError *e = nil;
            NSString *item = [oldPath stringByAppendingPathComponent:sub];
            NSString *destination = [_path stringByAppendingPathComponent:sub];
            if (![fm fileExistsAtPath:destination]) {
                NSLog(@"migrating %@ to %@", item, destination);
                [fm moveItemAtPath:item toPath:destination error:&e];
            }
            if (e) {
                NSLog(@"%@", [e description]);
            }
        }
        //clean up whatever is left
        NSError *e = nil;
        NSLog(@"removing %@", oldPath);
        [fm removeItemAtPath:oldPath error:&e];
        if (e) {
            NSLog(@"%@", [e description]);
        }
    }
}

- (void)setFileAttributes {
    if (storageType == UALocalStorageTypeCritical || storageType == UALocalStorageTypeOffline) {
        //mark path so that it will not be backed up by iCloud, or purged on low storage
        //note: this attribute is only meaningful in iOS 5.0.1+, but can be safely set in prior releases
        u_int8_t b = 1;
        setxattr([self.path fileSystemRepresentation], "com.apple.MobileBackup", &b, 1, 0, 0);
    }
}

- (void)dealloc {
    self.subpath = nil;
    self.oldPaths = nil;
    [super dealloc];
}

@end
