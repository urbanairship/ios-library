/* Copyright Airship and Contributors */

#if canImport(ActivityKit)

    import ActivityKit
    import Foundation

    struct DeliveryAttributes: ActivityAttributes {
        public typealias PizzaDeliveryStatus = ContentState

        public struct ContentState: Codable, Hashable {
            var stopsAway: Int
        }

        var orderNumber: String
    }

#endif
