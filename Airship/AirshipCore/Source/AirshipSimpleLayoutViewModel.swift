/* Copyright Airship and Contributors */

import Foundation
public import Combine

/// View model that owns the Thomas layout environment and its state.
/// Create one per layout session (e.g. per message) and pass it to ``AirshipSimpleLayoutView``.
/// Same view model = preserved state across view updates; new view model = fresh state.
///
/// - Note: For internal use only.  :nodoc:
@MainActor
public final class AirshipSimpleLayoutViewModel: ObservableObject {
    let environment: ThomasEnvironment

    public init(
        delegate: any ThomasDelegate,
        timer: (any AirshipTimerProtocol)? = nil,
        extensions: ThomasExtensions? = nil,
        dismissHandle: ThomasDismissHandle? = nil,
        stateStorage: (any LayoutDataStorage)? = nil
    ) {
        
        let dataStore: (any ThomasStateStorage)? = if let storage = stateStorage {
            DefaultThomasStateStorage(store: storage)
        } else {
            nil
        }
        
        self.environment = ThomasEnvironment(
            delegate: delegate,
            extensions: extensions,
            timer: timer,
            stateStorage: dataStore,
            dismissHandle: dismissHandle
        )
    }
}
