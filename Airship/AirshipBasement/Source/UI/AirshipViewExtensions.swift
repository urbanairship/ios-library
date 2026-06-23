/* Copyright Airship and Contributors */

import Foundation
public import SwiftUI

/// - Note: For internal use only. :nodoc:
@_spi(AirshipInternal)
public extension View {
    /// Wrapper to prevent linter warnings for deprecated onChange method
    /// - Parameters:
    ///   - value: The value to observe for changes.
    ///   - initial: A Boolean value that determines whether the action should be fired initially.
    ///   - action: The action to perform when the value changes.
    /// - Note: For internal use only. :nodoc:
    @ViewBuilder
    func airshipOnChangeOf<Value: Equatable>(_ value: Value, initial: Bool = false, _ action: @escaping (Value) -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {
            self.onChange(of: value, initial: initial, {
                action(value)
            })
        } else {
            self.onChange(of: value, perform: action)
        }
    }
    
    @ViewBuilder
    func airshipFocusableCompat(
        _ isFocusable: Bool = true
    ) -> some View {
        if #available(iOS 17.0, *) {
            self.focusable(isFocusable)
        } else {
            self
        }
    }

    @ViewBuilder
    func airshipApplyIf<Content: View>(
        _ predicate: @autoclosure () -> Bool,
        @ViewBuilder transform: (Self) -> Content
    ) -> some View {
        if predicate() {
            transform(self)
        } else {
            self
        }
    }

    @ViewBuilder
    func airshipApplyIfPresent<Value, Content: View>(
        _ value: Value?,
        @ViewBuilder transform: (Self, Value) -> Content
    ) -> some View {
        if let value {
            transform(self, value)
        } else {
            self
        }
    }

   

    @ViewBuilder
    func airshipGeometryGroupCompat() -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
            self.geometryGroup()
        } else {
            self.transformEffect(.identity)
        }
    }
}


