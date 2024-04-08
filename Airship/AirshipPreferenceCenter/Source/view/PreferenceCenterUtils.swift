/* Copyright Airship and Contributors */

import Foundation
import SwiftUI

#if canImport(AirshipCore)
import AirshipCore
#endif

extension View {
    @ViewBuilder
    func backgroundWithCloseAction(onClose: (()->())?) -> some View {
        ZStack {
            Rectangle()
                .foregroundColor(Color.clear)
                .background(Color.airshipTappableClear.ignoresSafeArea(.all)).simultaneousGesture(TapGesture().onEnded { _ in
                if let onClose = onClose {
                    onClose()
                }
            }).zIndex(0)
            self.zIndex(1)
        }
    }
}

extension String {
    func mask(_ type: PreferenceCenterConfig.ContactManagementItem.RegistrationOptions) -> String {
        switch type {
        case .email(_):
            return self.maskEmail
        case .sms(_):
            return self.maskPhoneNumber
        }
    }

    var maskEmail: String {
        let components = self.components(separatedBy: "@")
        return hideMidChars(components.first!) + "@" + components.last!
    }

    var maskPhoneNumber: String {
        return String(self.enumerated().map { index, char in
            return [self.count - 1, self.count - 2].contains(index) ?
            char : "*"
        })
    }

    private func hideMidChars(_ value: String) -> String {
        return String(value.enumerated().map { index, char in
            return [0, value.count, value.count].contains(index) ? char : "*"
        })
    }

    func deletePrefix(_ prefix: String) -> String {
        guard self.hasPrefix(prefix) else { return self }
        return String(self.dropFirst(prefix.count))
    }
}
