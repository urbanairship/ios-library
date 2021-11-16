/* Copyright Airship and Contributors */


import Foundation

/**
 * Protocol to run actions.
 */
protocol ActionRunnerProtocol {
    func run(_ actions: [String : Any])
}
