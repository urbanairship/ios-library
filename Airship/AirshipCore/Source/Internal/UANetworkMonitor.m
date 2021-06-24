/* Copyright Airship and Contributors */

#import "UANetworkMonitor.h"
#import "Network/Network.h"
#import "UAGlobal.h"
#import "NSObject+UAAdditions.h"
#import "UAUtils.h"

#if __has_include("AirshipCore/AirshipCore-Swift.h")
#import <AirshipCore/AirshipCore-Swift.h>
#elif __has_include("Airship/Airship-Swift.h")
#import <Airship/Airship-Swift.h>
#endif


@interface UANetworkMonitor()
@property(nonatomic, strong) nw_path_monitor_t pathMonitor  API_AVAILABLE(ios(12), tvos(12));
@property(nonatomic, assign) BOOL isConnected;
@end

@implementation UANetworkMonitor

- (instancetype)init {
    self = [super init];
    if (self) {
        if (@available(ios 12.0, tvOS 12.0, *)) {
            self.pathMonitor = nw_path_monitor_create();
            nw_path_monitor_set_queue(self.pathMonitor, dispatch_get_main_queue());
            UA_WEAKIFY(self)
            nw_path_monitor_set_update_handler(self.pathMonitor, ^(nw_path_t  _Nonnull path) {
                UA_STRONGIFY(self)
                nw_path_status_t status = nw_path_get_status(path);
                switch (status) {
                    case nw_path_status_satisfiable:
                    case nw_path_status_satisfied:
                        if (!self.isConnected) {
                            self.isConnected = YES;
                        }
                        break;
                    default:
                        if (self.isConnected) {
                            self.isConnected = NO;
                        }
                        break;
                }
            });
            nw_path_monitor_start(self.pathMonitor);
        }
    }

    return self;
}

- (UADisposable *)connectionUpdates:(void (^)(BOOL))callBack {
    return [self observeAtKeyPath:@"isConnected" withBlock:^(id  _Nonnull value) {
        callBack([value boolValue]);
    }];
}

- (BOOL)isConnected {
    if (@available(ios 12.0, tvOS 12.0, *)) {
        return _isConnected;
    } else {
        return [UAUtils connectionType] != UAConnectionTypeNone;
    }
}

@end
