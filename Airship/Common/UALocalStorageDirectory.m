/*
 Copyright 2009-2012 Urban Airship Inc. All rights reserved.
 
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

#import "UAGlobal.h"
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

+ (UALocalStorageDirectory *)localStorageDirectoryWithType:(UALocalStorageType)storageType withSubpath:(NSString *)subpathString withOldPaths:(NSSet *)oldPathsSet {
    return [[[UALocalStorageDirectory alloc] initWithStorageType:storageType withSubpath:subpathString withOldPaths:oldPathsSet] autorelease];
}

- (id)initWithStorageType:(UALocalStorageType)type withSubpath:(NSString *)subpathString withOldPaths:(NSSet *)oldPathsSet {
    if (self = [super init]) {
        self.subpath = subpathString;
        self.storageType = type;
        self.oldPaths = oldPathsSet;
        
        [self createIfNecessary];
        [self setFileAttributes];
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

- (NSString *)subDirectoryWithPathComponent:(NSString *)component {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *fullSubpath = [self.path stringByAppendingPathComponent:component];
    if (![fm fileExistsAtPath:fullSubpath]) {
        [fm createDirectoryAtPath:fullSubpath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return fullSubpath;
}

- (void)createIfNecessary {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    //create the directory on disk if needed
    if (![fm fileExistsAtPath:self.path]) {
        [fm createDirectoryAtPath:self.path withIntermediateDirectories:YES attributes:nil error:nil];
    }
        
    //migrate old path to new if present and non-equal
    for (NSString *p in oldPaths.allObjects) {
        if ([fm fileExistsAtPath:p] && ![self.path isEqualToString:p]) {
            [self migratePath:p];
        }
    }
}

//moves subpaths of oldPath to self.path and deletes oldPath when done.
//this really should not be so complicated but whatever
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
                UALOG(@"migrating %@ to %@", item, destination);
                [fm moveItemAtPath:item toPath:destination error:&e];
            }
            if (e) {
                UALOG(@"%@", [e description]);
            }
        }
        //clean up whatever is left
        NSError *e = nil;
        UALOG(@"removing %@", oldPath);
        [fm removeItemAtPath:oldPath error:&e];
        if (e) {
            UALOG(@"%@", [e description]);
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
