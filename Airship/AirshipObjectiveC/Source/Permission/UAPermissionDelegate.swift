/* Copyright Airship and Contributors */

public import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

/// Permissions manager delegate protocol for Objective-C compatibility
@objc
public protocol UAPermissionDelegate {

    /// Called when a permission needs to be checked.
    /// - Parameters:
    ///   - completionHandler: Completion handler that must be called with the permission status
    @objc
    func checkPermissionStatus(completionHandler: @escaping (UAPermissionStatus) -> Void)

    /// Called when a permission should be requested.
    /// - Parameters:
    ///   - completionHandler: Completion handler that must be called with the permission status
    /// - Note: A permission might be already granted when this method is called.
    @objc
    func requestPermission(completionHandler: @escaping (UAPermissionStatus) -> Void)
}

/// Internal wrapper to bridge between the Objective-C delegate and Swift async API
internal class UAPermissionDelegateWrapper: AirshipPermissionDelegate {
    private weak var delegate: (any UAPermissionDelegate)?

    init(delegate: any UAPermissionDelegate) {
        self.delegate = delegate
    }

    @MainActor
    func checkPermissionStatus() async -> AirshipPermissionStatus {
        guard let delegate = delegate else {
            return .notDetermined
        }

        return await withCheckedContinuation { continuation in
            delegate.checkPermissionStatus { status in
                continuation.resume(returning: status.airshipStatus)
            }
        }
    }

    @MainActor
    func requestPermission() async -> AirshipPermissionStatus {
        guard let delegate = delegate else {
            return .notDetermined
        }

        return await withCheckedContinuation { continuation in
            delegate.requestPermission { status in
                continuation.resume(returning: status.airshipStatus)
            }
        }
    }
}
