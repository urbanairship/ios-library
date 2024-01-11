/* Copyright Airship and Contributors */

import Foundation

actor Notifier {
    private var notifyBlocks: [@Sendable () -> Void] = []

    func notify() {
        notifyBlocks.forEach { block in block() }
    }

    func addOnNotify(_ block: @escaping @Sendable () -> Void) {
        self.notifyBlocks.append(block)
    }

}
