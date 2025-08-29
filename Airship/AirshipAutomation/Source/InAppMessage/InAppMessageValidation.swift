/* Copyright Airship and Contributors */

import Foundation

#if canImport(AirshipCore)
import AirshipCore
#endif

extension InAppMessage {
    func validate() -> Bool {
        if !self.displayContent.validate() {
            AirshipLogger.debug("Messages require valid display content")
            return false
        }

        return true
    }
}

extension InAppMessageDisplayContent.Banner {
    private static let maxButtons:Int = 2

    func validate() -> Bool {
        if (self.heading?.text ?? "").isEmpty && (self.body?.text ?? "").isEmpty {
            AirshipLogger.debug("Banner must have either its body or heading defined.")
            return false
        }

        if self.buttons?.count ?? 0 > Self.maxButtons {
            AirshipLogger.debug("Banner allows a maximum of \(Self.maxButtons) buttons")
            return false
        }

        return true
    }
}

extension InAppMessageDisplayContent.Modal {
    func validate() -> Bool {
        if (self.heading?.text ?? "").isEmpty && (self.body?.text ?? "").isEmpty {
            AirshipLogger.debug("Modal display must have either its body or heading defined.")
            return false
        }

        return true
    }
}

extension InAppMessageDisplayContent.Fullscreen {

    func validate() -> Bool {
        if (self.heading?.text ?? "").isEmpty && (self.body?.text ?? "").isEmpty {
            AirshipLogger.debug("Full screen display must have either its body or heading defined.")
            return false
        }

        return true
    }
}

extension InAppMessageDisplayContent.HTML {
    func validate() -> Bool {
        if self.url.isEmpty {
            AirshipLogger.debug("HTML display must have a non-empty URL.")
            return false
        }

        return true
    }
}

extension InAppMessageTextInfo {
    func validate() -> Bool {
        if (self.text.isEmpty) {
            AirshipLogger.debug("In-app text infos require nonempty text")
            return false
        }

        return true
    }
}

extension InAppMessageButtonInfo {
    private static let minIdentifierLength:Int = 1
    private static let maxIdentifierLength:Int = 100

    func validate() -> Bool {
        if self.label.text.isEmpty {
            AirshipLogger.debug("In-app button infos require a nonempty label")
            return false
        }

        if identifier.count < Self.minIdentifierLength || identifier.count > Self.maxIdentifierLength {
            AirshipLogger.debug("In-app button infos require an identifier between [\(Self.minIdentifierLength), \(Self.maxIdentifierLength)] characters")
            return false
        }

        return true
    }
}
