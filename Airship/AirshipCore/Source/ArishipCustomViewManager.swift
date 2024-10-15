import Foundation
public import SwiftUI
/**
  * Internal only
  * :nodoc:
  */
public typealias AirshipCustomViewBuilder = (AirshipJSON?) -> AnyView

/**
 * Internal only
 * :nodoc:
 */
public final class AirshipCustomViewManager {
    public static let shared = AirshipCustomViewManager()
    var builders: [String: AirshipCustomViewBuilder] = [:]

    /**
     * Internal only
     * :nodoc:
     */
    public func register(name: String, builder: @escaping AirshipCustomViewBuilder) {
        DispatchQueue.main.async {
            self.builders[name] = builder
        }
    }

    /**
     * Internal only
     * :nodoc:
     */
    @MainActor
    public func unregisterCustomViews(names: String...) {
        names.forEach { name in
            self.builders.removeValue(forKey: name)
        }
    }

    /**
     * Internal only
     * :nodoc:
     */
    @MainActor
    public func unregisterAllCustomViews() {
        self.builders.removeAll()
    }

    @ViewBuilder
    @MainActor
    internal func makeCustomView(name: String, json: AirshipJSON?) -> some View {
        if let block = builders[name] {
            block(json)
        } else {
            /// Empty views don't receive a callback on their onAppear method so we use a hidden shape instead
            Rectangle()
                .hidden()
                .onAppear{
                AirshipLogger.error("Failed to execute custom view build block, no block found for name '\(name)'")
            }
        }
    }
}
