/* Copyright Airship and Contributors */

import Foundation
import Combine

#if !os(watchOS)

@available(iOS 13.0.0, tvOS 13.0, *)
final class KeyboardResponder: ObservableObject {
    @Published private(set) var keyboardHeight: Double = 0

#if !os(tvOS)
    private let keyboardWillShow = NotificationCenter.default
        .publisher(for: UIResponder.keyboardWillShowNotification)
        .map { $0.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect ?? CGRect.zero }
        .map { Double($0.height) }
    
    private let keyboardWillHide = NotificationCenter.default
        .publisher(for: UIResponder.keyboardWillHideNotification)
        .map { _ in 0.0 }
    
    init() {
        _ = Publishers.Merge(keyboardWillShow, keyboardWillHide)
            .subscribe(on: DispatchQueue.main)
            .assign(to: \.self.keyboardHeight, on:self)
    }
#endif
}

#endif
