/* Copyright Airship and Contributors */

import SwiftUI
import Combine

/// NOTE: For internal use only. :nodoc:
@MainActor
public final class AirshipEmbeddedViewModel : ObservableObject {
    /// An array of embedded infos
    @Published
    public var embeddedInfos: [AirshipEmbeddedInfo] = []

    private var subscription: AnyCancellable?

    /// Creates a new view model for the given embedded ID .
    ///
    /// - Parameters:
    ///   - embeddedID: The embedded ID to filter the embeddedInfos on.
    public convenience init(embeddedID: String) {
        self.init { info in
            info.embeddedID == embeddedID
        }
    }

    /// Creates a new view model for the given embedded IDs.
    ///
    /// - Parameters:
    ///   - embeddedID: An array of embedded IDs to filter the embeddedInfos on.
    public convenience init(embeddedIDs: [String]) {
        let set = Set(embeddedIDs)
        self.init { info in
            set.contains(info.embeddedID)
        }
    }

    /// Creates a new view model  for embedded infos.
    public convenience init() {
        self.init { info in
            return true
        }
    }
    /// Creates a new view model with the given predicate.
    ///
    /// - Parameters:
    ///   - predicate: A predicate to filter out AirshipEmbeddedInfo.
    public init(predicate: @escaping @MainActor (AirshipEmbeddedInfo) -> Bool) {
        subscription = AirshipEmbeddedViewManager.shared.publisher
            .map { array in
                array.filter { predicate($0.embeddedInfo) }
                    .map { $0.embeddedInfo }
            }
            .removeDuplicates()
            .assign(to: \.embeddedInfos, on: self)
    }


}
