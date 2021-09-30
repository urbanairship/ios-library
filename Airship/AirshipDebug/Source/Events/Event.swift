/* Copyright Airship and Contributors */

import UIKit

#if canImport(AirshipCore)
import AirshipCore
#elseif canImport(AirshipKit)
import AirshipKit
#endif


/**
 * A wrapper for representing an Airship event in the Debug UI
 */
struct AirshipEvent {
    let prettyTypes:[String:String] = [
        "app_init" : "App Initialization",
        "location" : "Location",
        "region_event" : "Region",
        "screen_tracking" : "Screen Tracking",
        "custom_event" : "Custom",
        "enhanced_custom_event" : "Enhanced Custom",
        "in_app_resolution" : "In-app Resolution",
        "in_app_display" : "In-app Display",
        "app_background" : "Backgound",
        "app_foreground" : "Foreground",
        "push_arrived" : "Push Arrived",
        "associate_identifiers" : "Associate Identifiers",
        "install_attribution" : "Install Attribution"
    ]

    /**
     * The unique event ID.
     */
    var eventID:String

    /**
     * The event's type.
     */
    var eventType:String

    /**
     * The time the event was created.
     */
    var time:Double

    /**
     * The event's data description.
     */
    var data:String


    init(event: Event, identifier: String, date: Date) {
        self.data = String(data: try! JSONSerialization.data(withJSONObject:event.data, options:.prettyPrinted), encoding:.utf8) ?? event.data.description
        self.time = date.timeIntervalSince1970
        self.eventType = prettyTypes[event.eventType] ?? event.eventType
        self.eventID = identifier
    }

    init(eventData:EventData) {
        self.data = eventData.data!
        self.time = eventData.time
        self.eventType = prettyTypes[eventData.eventType!] ?? eventData.eventType!
        self.eventID = eventData.eventID!
    }
}
