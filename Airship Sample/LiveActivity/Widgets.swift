import Foundation
import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
    import ActivityKit
#endif

@main
struct Widgets: WidgetBundle {
    var body: some Widget {
        #if canImport(ActivityKit)
            DeliveryActivityWidget()
        #endif
    }
}
