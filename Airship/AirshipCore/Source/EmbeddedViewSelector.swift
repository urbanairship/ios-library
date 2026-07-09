/* Copyright Airship and Contributors */

import Foundation

@MainActor
final class EmbeddedViewSelector {
    @MainActor
    static let shared: EmbeddedViewSelector = EmbeddedViewSelector()

    private var lastDisplayed: [String: String] = [:]

    func onViewDisplayed(_ info: AirshipEmbeddedInfo) {
        AirshipLogger.trace("Updating last displayed for \(info.embeddedID): \(info.instanceID)")
        lastDisplayed[info.embeddedID] = info.instanceID
    }

    func selectView(
        embeddedID: String,
        views: [AirshipEmbeddedContentView],
        selection: AirshipEmbeddedSelection = .priority
    ) -> AirshipEmbeddedContentView? {
        switch selection {
        case .instance(let instanceID):
            let view = views.first(where: { view in
                view.embeddedInfo.instanceID == instanceID
            })

            if view != nil {
                AirshipLogger.trace("Selecting targeted instance view for \(embeddedID): \(instanceID)")
            } else {
                AirshipLogger.trace("No pending view matches targeted instance \(instanceID) for \(embeddedID)")
            }

            return view

        case .comparator(let comparator):
            let view = views.sorted(by: { f, s in
                comparator(f.embeddedInfo, s.embeddedInfo) == .orderedAscending
            }).first

            if let view {
                AirshipLogger.trace("Selecting comparator sorted view for \(embeddedID): \(view.embeddedInfo)")
            }

            return view

        case .priority:
            guard
                let lastInstanceID = lastDisplayed[embeddedID],
                let last = views.first(where: { view in
                    view.embeddedInfo.instanceID == lastInstanceID
                })
            else {
                let view =  views.sorted(by: { f, s in
                    f.embeddedInfo.priority < s.embeddedInfo.priority
                }).first

                if let view {
                    AirshipLogger.trace("Selecting priority sorted view for \(embeddedID): \(view.embeddedInfo)")
                }

                return view
            }

            AirshipLogger.trace("Selecting previously displayed view for \(embeddedID): \(last.embeddedInfo.instanceID)")
            return last
        }
    }
}
